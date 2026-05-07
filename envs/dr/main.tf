terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "aws" {
  region = "us-west-2"

  default_tags {
    tags = {
      Environment = "dr"
      Project     = "multi-region-migration"
      ManagedBy   = "terraform"
    }
  }
}

locals {
  name = "migration-dr"
  tags = var.tags
}

# Pull the primary DB ARN from the primary env's remote state.
# Apply primary first, then populate primary_state_bucket in terraform.tfvars.
data "terraform_remote_state" "primary" {
  backend = "s3"
  config = {
    bucket = var.primary_state_bucket
    key    = "primary/terraform.tfstate"
    region = "us-east-1"
  }
}

# ── VPC ───────────────────────────────────────────────────────────────────────

module "vpc" {
  source = "../../modules/vpc"

  name               = local.name
  vpc_cidr           = "10.1.0.0/16" # non-overlapping with primary (10.0.0.0/16)
  az_count           = 3
  single_nat_gateway = true # warm standby — one NAT GW to reduce idle cost
  enable_flow_logs   = true

  tags = local.tags
}

# ── Compute ───────────────────────────────────────────────────────────────────

module "compute" {
  source = "../../modules/compute"

  name               = local.name
  vpc_id             = module.vpc.vpc_id
  public_subnet_ids  = module.vpc.public_subnet_ids
  private_subnet_ids = module.vpc.private_subnet_ids

  instance_type              = "t3.small"
  min_size                   = 1
  max_size                   = 6
  desired_capacity           = 1 # scale up to match primary on failover
  target_cpu_percent         = 60
  health_check_path          = "/health"
  enable_deletion_protection = false # DR infra can be rebuilt

  tags = local.tags
}

# ── RDS Read Replica ──────────────────────────────────────────────────────────

module "rds" {
  source = "../../modules/rds"

  name                  = local.name
  vpc_id                = module.vpc.vpc_id
  db_subnet_ids         = module.vpc.db_subnet_ids
  app_security_group_id = module.compute.ec2_security_group_id

  engine_version        = "16.3"
  instance_class        = "db.t3.medium"
  multi_az              = false # warm standby; promote + enable Multi-AZ on failover
  allocated_storage     = 100
  max_allocated_storage = 500

  backup_retention_period = 1 # keep 1 day on the replica; primary holds full history
  deletion_protection     = false
  skip_final_snapshot     = true # replica can be recreated from primary

  # Wires this instance as a cross-region read replica of the primary DB
  replicate_source_db_arn = data.terraform_remote_state.primary.outputs.db_instance_arn

  tags = local.tags
}
