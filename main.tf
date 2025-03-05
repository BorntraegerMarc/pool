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

resource "aws_ecr_repository" "pool-ms2" {
  name = "pool/ms2"
}

################################################################################
# Docker Build and Push
# Bad practice to use Terraform Provisioners. But for simplicity we're combining build step with deployment. In prod we should hve separate CI/CD pipelines.
################################################################################
resource "null_resource" "build_and_push_ms1" {
  depends_on = [aws_ecr_repository.pool-ms1]

  provisioner "local-exec" {
    command = <<EOT
      aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin ${aws_ecr_repository.pool-ms1.repository_url}
      docker build -t ${aws_ecr_repository.pool-ms1.repository_url}:latest --platform=linux/arm64 ./microservice-1
      docker push ${aws_ecr_repository.pool-ms1.repository_url}:latest
    EOT
  }
}

resource "null_resource" "build_and_push_ms2" {
  depends_on = [aws_ecr_repository.pool-ms2]

  provisioner "local-exec" {
    command = <<EOT
      aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin ${aws_ecr_repository.pool-ms2.repository_url}
      docker build -t ${aws_ecr_repository.pool-ms2.repository_url}:latest --platform=linux/arm64 ./microservice-2
      docker push ${aws_ecr_repository.pool-ms2.repository_url}:latest
    EOT
  }
}

################################################################################
# EKS
################################################################################
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.31"

  depends_on = [aws_ecr_repository.pool-ms1, aws_ecr_repository.pool-ms2]

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
# Aurora
################################################################################
resource "aws_rds_cluster" "pooldb" {
  cluster_identifier          = "pooldb"
  engine                      = "aurora-postgresql"
  engine_mode                 = "provisioned"
  engine_version              = "16.4"
  database_name               = "pooldb"
  master_username             = "pooluser"
  manage_master_user_password = true
  storage_encrypted           = true
  skip_final_snapshot         = true
  db_subnet_group_name        = aws_db_subnet_group.pooldb-subnet-group.name
  vpc_security_group_ids      = [aws_security_group.pooldb-db.id]
  enable_http_endpoint        = true # For easier debugging; Remove in prod
  # db_cluster_parameter_group_name = aws_db_parameter_group.pooldb-parameter-group.name

  serverlessv2_scaling_configuration {
    min_capacity             = 0
    max_capacity             = 10
    seconds_until_auto_pause = 3600
  }
}

resource "aws_rds_cluster_instance" "pooldbinstance" {
  cluster_identifier = aws_rds_cluster.pooldb.id
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.pooldb.engine
  engine_version     = aws_rds_cluster.pooldb.engine_version
}

resource "aws_db_subnet_group" "pooldb-subnet-group" {
  name       = "pooldb-subnet-group"
  subnet_ids = module.vpc.private_subnets
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

################################################################################
# Supporting Resources - Pod Identity
################################################################################
data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }

    actions = [
      "sts:AssumeRole",
      "sts:TagSession"
    ]
  }
}

resource "aws_iam_role" "pool" {
  name               = "eks-pod-identity-pool"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_role_policy_attachment" "secrets" {
  policy_arn = "arn:aws:iam::aws:policy/SecretsManagerReadWrite" # Amazon Managed policy - that's why we can hardcode the value because it should always exist
  role       = aws_iam_role.pool.name
}

resource "aws_eks_pod_identity_association" "pool" {
  cluster_name    = local.name
  namespace       = "pool"
  service_account = "pool-sa"
  role_arn        = aws_iam_role.pool.arn
}

################################################################################
# Supporting Resources - Security Group Aurora DB
################################################################################

resource "aws_security_group" "pooldb-db" {
  name   = "pooldb-sg"
  vpc_id = module.vpc.vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "allow-from-private-subnets" {
  security_group_id = aws_security_group.pooldb-db.id
  cidr_ipv4         = module.vpc.vpc_cidr_block
  from_port         = 5432
  to_port           = 5432
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "allow-all" {
  security_group_id = aws_security_group.pooldb-db.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

resource "aws_vpc_security_group_egress_rule" "allow-all-ipv6" {
  security_group_id = aws_security_group.pooldb-db.id
  cidr_ipv6         = "::/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}
