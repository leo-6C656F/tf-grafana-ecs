# tf-grafana-ecs

## What is this?

This Terraform script allows you to deploy Grafana on AWS ECS, with a connected database on AWS RDS Postgres. The project is structured into separate files for straightforward component identification. We've tested this script with Grafana 10.4.

## How to run?

### 1. `plan`

`terraform plan -out "tfplan" -var-file=prod.tfvars`

### 2. `apply`

`terraform apply "tfplan"  -var-file=prod.tfvars`

## How do I get delete everything?

`terraform destroy`
