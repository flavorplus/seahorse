provider "aws" {
  region = var.region
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.eks_auth.token
  }
}

data "aws_eks_cluster_auth" "eks_auth" {
  name = module.eks.cluster_name
}


data "aws_availability_zones" "available" {
  # Exclude local zones
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

locals {
  vpc_cidr = "10.0.0.0/16"
  azs      = slice(data.aws_availability_zones.available.names, 0, 3)
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name                   = "${var.name_prefix}-eks-cluster"
  cluster_endpoint_public_access = true

  enable_cluster_creator_admin_permissions = true

  cluster_compute_config = {
    enabled    = true
    node_pools = ["general-purpose"]
  }

  cluster_addons = {
    coredns = {
      enabled = true
    }
  }

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.name_prefix}-vpc"
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
}

resource "helm_release" "cf_gitops_runtime" {
  name             = "cf-gitops-runtime"
  namespace        = "codefresh-gitops-runtime"
  chart            = "oci://quay.io/codefresh/gitops-runtime"
  create_namespace = true

  values = [
    <<EOF
    installer:
      skipValidation: true
    global:
      codefresh:
        accountId: "${var.codefresh_account_id}"
        userToken:
          token: "${var.codefresh_user_token}"
      runtime:
        name: "${module.eks.cluster_name}-runtime"
        gitCredentials:
          username: "${var.github_username}"
          password: 
            value: "${var.github_token}"
    EOF
  ]
  depends_on = [module.eks, data.aws_eks_cluster_auth.eks_auth]
  lifecycle {
    ignore_changes = [
      metadata
    ]
  }
}
