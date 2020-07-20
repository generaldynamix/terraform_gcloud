#!/bin/bash
terraform destroy -target='google_compute_instance.personal["super-provider"]'
terraform apply -target='google_compute_instance.personal["super-provider"]' -target='google_dns_record_set.personal["super-provider"]' -target='consul_node.personal["super-provider"]' -target='consul_service.personal["super-provider"]'
