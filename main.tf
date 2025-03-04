provider "aws" {
  region = local.region
}

data "aws_availability_zones" "available" {
  # Exclude local zones
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

locals {
  name            = "ex-${basename(path.cwd)}"
  cluster_version = "1.31"
  region          = "us-east-1"

  vpc_cidr = "10.0.0.0/16"
  azs      = slice(data.aws_availability_zones.available.names, 0, 3)

  tags = {
    Test       = local.name
    GithubRepo = "terraform-aws-eks"
    GithubOrg  = "terraform-aws-modules"
  }
}

################################################################################
# ECR
################################################################################
resource "aws_ecr_repository" "pool-ms1" {
  name = "pool/ms1"
}

################################################################################
# Docker Build and Push
################################################################################
resource "null_resource" "build_and_push" {
  depends_on = [aws_ecr_repository.pool-ms1]

  # Bad practice to use Terraform Provisioners. But for simplicity we're combining build step with deployment. In prod we should hve separate CI/CD pipelines.
  provisioner "local-exec" {
    command = <<EOT
      aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 861567669929.dkr.ecr.us-east-1.amazonaws.com
      docker build -t 861567669929.dkr.ecr.us-east-1.amazonaws.com/pool/ms1:latest --platform=linux/arm64 ./microservice-1
      docker push 861567669929.dkr.ecr.us-east-1.amazonaws.com/pool/ms1:latest
    EOT
  }
}

################################################################################
# EKS Module
################################################################################
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.31"

  depends_on = [aws_ecr_repository.pool-ms1]

  cluster_name                   = local.name
  cluster_version                = local.cluster_version
  cluster_endpoint_public_access = true

  enable_cluster_creator_admin_permissions = true # Adds the current caller identity as an administrator via cluster access entry

  cluster_compute_config = {
    enabled    = true
    node_pools = ["system"]
  }

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  tags = local.tags
}

################################################################################
# Supporting Resources
################################################################################
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = local.name
  cidr = local.vpc_cidr

  azs             = local.azs
  private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 4, k)]
  public_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 48)]
  intra_subnets   = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 52)]

  enable_nat_gateway = true
  single_nat_gateway = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }

  tags = local.tags
}
