variable "name" {
    default = "tf-grafana"
}

variable "env" {
    default = "prod"
}

variable "terraform_prefix" {
    default = "tfg"
}

variable "team" {
    default = "sre"
}

variable "product" {
    default = "terraform"
}

variable "description" {
    default = "Created via Terraform"
}
variable "grafanaPlugins" {
    default = "Grafana Variable"
}

variable "dataSourceCloudWatch" {
}

variable "dataSourceAthena" {
}

variable "dataSourceXray" {
}

variable "dataSourceBigQuery" {
}

variable "kmsAlias" {
}

variable "whiteListIP" {
}