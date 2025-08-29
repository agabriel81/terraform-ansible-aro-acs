variable "location" {
  type = string
  default = "northeurope"
}

variable "resourcegroup_name" {
  type = string
  default = "aro-agabriel"
}

variable "cluster_name" {
  type = string
  default = "aro-cluster"
}

variable "pull_secret" {
    type = string
}

variable "cluster_domain" {
    type = string
    default = "agabriel"
}

variable "cluster_version" {
    type = string
    default = "4.17.27"
}

variable "vnet_name" {
    type = string
    default = "aro-vnet"
}

variable "vnet_cidr" {
    type = string
    default = "10.0.0.0/22"
}

variable "master_subnet" {
    type = string
    default = "master-subnet"
}

variable "master_subnet_cidr" {
    type = string
    default = "10.0.0.0/24"
}

variable "worker_subnet" {
    type = string
    default = "worker-subnet"
}

variable "worker_subnet_cidr" {
    type = string
    default = "10.0.1.0/24"
}

