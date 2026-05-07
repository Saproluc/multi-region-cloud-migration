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
  region = "us-east-1"

  default_tags {
    tags = {
      Environment = "primary"
      Project     = "multi-region-migration"
      ManagedBy   = "terraform"
    }
  }
}

locals {
  name = "migration-primary"
  tags = var.tags
}

# ── VPC ───────────────────────────────────────────────────────────────────────

module "vpc" {
  source = "../../modules/vpc"

  name               = local.name
  vpc_cidr           = "10.0.0.0/16"
  az_count           = 3
  single_nat_gateway = false # HA: one NAT GW per AZ
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
  min_size                   = 2
  max_size                   = 6
  desired_capacity           = 2
  target_cpu_percent         = 60
  health_check_path          = "/health"
  enable_deletion_protection = true

  tags = local.tags
}

# ── RDS ───────────────────────────────────────────────────────────────────────

module "rds" {
  source = "../../modules/rds"

  name                  = local.name
  vpc_id                = module.vpc.vpc_id
  db_subnet_ids         = module.vpc.db_subnet_ids
  app_security_group_id = module.compute.ec2_security_group_id

  engine_version        = "16.3"
  instance_class        = "db.t3.medium"
  multi_az              = true
  allocated_storage     = 100
  max_allocated_storage = 500

  backup_retention_period = 7
  deletion_protection     = true
  skip_final_snapshot     = false

  # replicate_source_db_arn unset → this is the primary instance

  tags = local.tags
}
