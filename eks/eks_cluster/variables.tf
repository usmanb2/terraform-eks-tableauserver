variable "cluster_name" {
    type = string
    default = "eks_cluster"
}

variable "public_subnets" {
    description = "List of all the Public Subnets"
}

variable "private_subnets" {
    description = "List of all the Private Subnets"
}