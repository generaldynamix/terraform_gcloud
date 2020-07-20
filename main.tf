terraform {
  backend "consul" {
    address = "35.193.165.61:8500"
    scheme  = "http"
    path    = "config/terraform_state"
  }
}

provider "google" {
 credentials = file("credentials.json")
 project     = "clever-span-283508"
 region      = "europe-north1"
 zone = "europe-north1-b"
}

provider "google" {
 credentials = file("credentials.json")
 project     = "clever-span-283508"
 region      = "europe-west1"
 zone = "europe-west1-b"
 alias = "west1"
}

provider "google" {
 credentials = file("credentials.json")
 project     = "clever-span-283508"
 region      = "europe-west2"
 zone = "europe-west2-b"
 alias = "west2"
}

provider "consul" {
    address = "35.193.165.61:8500"
    datacenter = "dc1"
}



# list of localizations

data "consul_keys" "lang" {
key {
    name = "lang"
    path = "/lang/list"
}
}

#list of personal demos

data "consul_keys" "demos" {
key {
    name = "demos"
    path = "/lang/personaldemos"
}
}

resource "google_dns_managed_zone" "prod" {
  name     = "hydratesting"
  dns_name = "hydratesting.ml."
}

#create default test servers (lang-demo.domain) with every day rollback

resource "google_compute_instance" "default" {
  for_each = jsondecode(data.consul_keys.lang.var.lang)
  name = "${each.key}-demo"
  machine_type = "f1-micro"

  
  boot_disk {
    initialize_params {
      image = "nginx-consul-s3"
      type = "pd-standard"
    }
    auto_delete = "true"
  }

  network_interface {
    network = "default"
    subnetwork = "default"
    access_config {
      #public_ptr_domain_name = "${each.key}-demo.hydratesting.ml"
    }
  }
}

# add dns

resource "google_dns_record_set" "default" {
  for_each = jsondecode(data.consul_keys.lang.var.lang)
  name = "${google_compute_instance.default[each.key].name}.${google_dns_managed_zone.prod.dns_name}"
  type = "A"
  ttl  = 300
  
  managed_zone = google_dns_managed_zone.prod.name

  rrdatas = [google_compute_instance.default[each.key].network_interface[0].access_config[0].nat_ip]
}

# add consul node

resource "consul_node" "default" {
  for_each = jsondecode(data.consul_keys.lang.var.lang)
  address = "${google_compute_instance.default[each.key].network_interface[0].network_ip}"
  name    = "${google_compute_instance.default[each.key].name}"
}

# add consul service

resource "consul_service" "default" {
  for_each = jsondecode(data.consul_keys.lang.var.lang)
  name    = "demo"
  node    = "${google_compute_instance.default[each.key].name}"
  port    = 80
  depends_on = [
     consul_node.default
  ]
}

# create individual demo servers (lang-client.hydratesting.ml)


resource "google_compute_instance" "personal" {
  for_each = jsondecode(data.consul_keys.demos.var.demos)
  name = "${each.key}-${each.value}-personaldemo"
  machine_type = "f1-micro"
  provider = google.west1

  
  boot_disk {
    initialize_params {
      image = "nginx-consul-s3"
      type = "pd-standard"
    }
    auto_delete = "true"
  }

  network_interface {
    network = "default"
    subnetwork = "default"
    access_config {
      #public_ptr_domain_name = "${each.key}-${each.value}-personaldemo.hydratesting.ml."
    }
  }
  # disable snapshot recovery
metadata_startup_script =  "sudo sed -e 's/.*recovery.sh.*//' -i /etc/crontab" 


}

# add dns

resource "google_dns_record_set" "personal" {
  for_each = jsondecode(data.consul_keys.demos.var.demos)
  name = "${google_compute_instance.personal[each.key].name}.${google_dns_managed_zone.prod.dns_name}"
  type = "A"
  ttl  = 300
  
  managed_zone = google_dns_managed_zone.prod.name

  rrdatas = [google_compute_instance.personal[each.key].network_interface[0].access_config[0].nat_ip]
}

# add consul node

resource "consul_node" "personal" {
  for_each = jsondecode(data.consul_keys.demos.var.demos)
  address = "${google_compute_instance.personal[each.key].network_interface[0].network_ip}"
  name    = "${google_compute_instance.personal[each.key].name}"
}

# add consul service

resource "consul_service" "personal" {
  for_each = jsondecode(data.consul_keys.demos.var.demos)
  name    = "demo"
  node    = "${google_compute_instance.personal[each.key].name}"
  port    = 80
    depends_on = [
     consul_node.personal
  ]
}

#create presentation servers (lang-presentation-demo.domain) with every day rollback and firewall

resource "google_compute_instance" "present" {
  for_each = jsondecode(data.consul_keys.lang.var.lang)
  name = "${each.key}-presentation-demo"
  machine_type = "f1-micro"
  provider = google.west2

  
  boot_disk {
    initialize_params {
      image = "nginx-consul-s3"
      type = "pd-standard"
    }
    auto_delete = "true"
  }

  network_interface {
    network = "default"
    subnetwork = "default"
    access_config {
      #public_ptr_domain_name = "${each.key}-presentation-demo.hydratesting.ml."
    }
  }
  #disable all access and allow 22 for test only
    metadata_startup_script = "iptables -A INPUT  -s 10.0.0.0/8,127.0.0.0/8,100.64.0.0/10,172.16.0.0/12,192.168.0.0/16 -j ACCEPT && iptables -A INPUT  -p tcp --dport 22 -j ACCEPT && iptables -A INPUT  -m state --state ESTABLISHED,RELATED -j ACCEPT && iptables -A INPUT -j REJECT"
}

# add dns

resource "google_dns_record_set" "present" {
  for_each = jsondecode(data.consul_keys.lang.var.lang)
  name = "${google_compute_instance.present[each.key].name}.${google_dns_managed_zone.prod.dns_name}"
  type = "A"
  ttl  = 300
  
  managed_zone = google_dns_managed_zone.prod.name

  rrdatas = [google_compute_instance.present[each.key].network_interface[0].access_config[0].nat_ip]
}

# add consul node

resource "consul_node" "present" {
  for_each = jsondecode(data.consul_keys.lang.var.lang)
  address = "${google_compute_instance.present[each.key].network_interface[0].network_ip}"
  name    = "${google_compute_instance.present[each.key].name}"
}

# add consul service

resource "consul_service" "present" {
  for_each = jsondecode(data.consul_keys.lang.var.lang)
  name    = "demo"
  node    = "${google_compute_instance.present[each.key].name}"
  port    = 80
    depends_on = [
     consul_node.present
  ]
}