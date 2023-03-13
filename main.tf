provider "aws" {
  region = "us-east-2"
  profile = "bprofile"
}

data "aws_kms_secrets" "creds" {
  secret {
    name    = "db"
    payload = file("rds-creds.yml.encrypted")
  }
}

locals {
  db_creds = yamldecode(data.aws_kms_secrets.creds.plaintext["db"])
}

module "network" {
  source              = "./network"
  vpc_name            = var.vpc_name
  vpc_cidr            = var.vpc_cidr
  eks_cluster_name    = var.eks_cluster_name
  cidr_block_igw      = var.cidr_block_igw
}

module "eks_cluster" {
  source              = "./eks/eks_cluster"
  cluster_name        = var.eks_cluster_name
  public_subnets      = module.network.aws_subnets_public
  private_subnets     = module.network.aws_subnets_private
} 

module "eks_node_group" {
  source            = "./eks/eks_node_group"
  eks_cluster_name  = module.eks_cluster.cluster_name
  node_group_name   = var.node_group_name
  subnet_ids        = [ module.network.aws_subnets_private[0], module.network.aws_subnets_private[1] ]
  instance_types    = var.ng_instance_types
  disk_size         = var.disk_size
  desired_nodes     = var.desired_nodes
  max_nodes         = var.max_nodes
  min_nodes         = var.min_nodes
}

module "fargate" {
  source                  = "./eks/fargate"
  eks_cluster_name        = module.eks_cluster.cluster_name
  fargate_profile_name    = var.fargate_profile_name
  subnet_ids              = module.network.aws_subnets_private
  kubernetes_namespace    = var.kubernetes_namespace
}

module "rds" {
  source               = "./rds"
  vpc_id               = module.network.vpc_id
  vpc_cidr             = var.vpc_cidr
  rds_subnet_ids       = module.network.aws_subnets_private
  subnet_group_name    = var.rds_subnet_group_name
  identifier           = var.rds_db_identifier
  allocated_storage    = var.rds_storage
  engine               = var.engine
  engine_version       = var.engine_version
  instance_class       = var.instance_class
  db_name              = var.rds_db_name
  username             = local.db_creds.username
  password             = local.db_creds.password
  parameter_group_name = var.rds_parameter_group_name
}

