# ---------------------------------------------------------------------------------------------------------------------
#REQUIRED PROVIDERS
# ---------------------------------------------------------------------------------------------------------------------
terraform {
   required_providers {
    aws = {
      source  = "hashicorp/aws"
      } 
      grafana = {
         source  = "grafana/grafana"
         version = "2.3.3"
      }
   }
}


# ---------------------------------------------------------------------------------------------------------------------
#AWS SPECIFIC INFORMATION
# ---------------------------------------------------------------------------------------------------------------------
provider "aws" {
	region = "us-east-2"
  shared_credentials_files = ["$HOME/.aws/credentials"]

    default_tags {
    tags = {
      env = "${var.env}"
      team = "${var.team}"
      product = "${var.product}"
      project = "${var.name}"
      pet = "${random_pet.this.id}"
      generated_by = "Terraform ${var.env} ${var.terraform_prefix}"
    }
  }
}


# ---------------------------------------------------------------------------------------------------------------------
# RANDOM PET NAME TO MAKE THE PROJECT AND RESOURCE UNIQUE
# ---------------------------------------------------------------------------------------------------------------------
resource "random_pet" "this" {
  length = 2
}
