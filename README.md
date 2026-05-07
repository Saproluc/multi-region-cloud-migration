# Multi-Region Cloud Migration

> **Infrastructure-as-Code toolkit for deploying a highly available, multi-region workload on AWS using reusable Terraform modules.**

---

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Repository Structure](#repository-structure)
- [Prerequisites](#prerequisites)
- [Modules](#modules)
  - [VPC Module](#vpc-module)
  - [Compute Module](#compute-module)
- [Usage](#usage)
- [Inputs](#inputs)
- [Outputs](#outputs)
- [Design Decisions](#design-decisions)
- [Contributing](#contributing)
- [License](#license)

---

## Overview

This repository provides production-grade Terraform modules for migrating workloads to AWS across multiple regions. Each module is independently deployable, fully parameterised, and designed to be composed into a root configuration that spans a **primary region** (active) and a **DR/secondary region** (standby).

Key capabilities:

- **Isolated, tiered networking** - public, private, and database subnet tiers carved automatically across 1-3 Availability Zones.
- **HA or DR NAT Gateway topology** - one NAT Gateway per AZ for high availability, or a single NAT Gateway for cost-optimised disaster-recovery standby.
- **VPC Flow Logs** - full-traffic capture shipped to CloudWatch Logs with configurable retention.
- **Auto-Scaled EC2 fleet** - Application Load Balancer fronting an Auto Scaling Group with a CPU target-tracking policy and rolling instance refresh.
- **Least-privilege security groups** - ALB accepts public HTTP; EC2 instances accept traffic exclusively from the ALB.
- **Zero hard-coded AMI IDs** - the compute module resolves the latest Amazon Linux 2023 AMI at plan time in whichever region Terraform targets.

---

## Architecture

```
                          +------------------------------------------+
                          |          AWS Region (Primary / DR)       |
                          |                                          |
  Internet -------------->|  Internet Gateway                        |
                          |       |                                  |
                          |  +----v-----------------------------------+  |
                          |  |       Public Subnets (x AZs)         |  |
                          |  |  NAT GW (per AZ or single)           |  |
                          |  |  Application Load Balancer            |  |
                          |  +-------------------+-------------------+  |
                          |                      |                      |
                          |  +-------------------v-------------------+  |
                          |  |      Private Subnets (x AZs)         |  |
                          |  |      Auto Scaling Group               |  |
                          |  |      EC2 Instances (AL2023)           |  |
                          |  +-------------------+-------------------+  |
                          |                      |                      |
                          |  +-------------------v-------------------+  |
                          |  |         DB Subnets (x AZs)           |  |
                          |  |  (No internet route - isolated)       |  |
                          |  +---------------------------------------+  |
                          +------------------------------------------+
```

The same module pair is deployed twice (once per region) with non-overlapping CIDR blocks, enabling future VPC Peering or AWS Transit Gateway cross-region routing.

---

## Repository Structure

```
multi-region-cloud-migration/
+-- modules/
    +-- vpc/                  # Networking: VPC, subnets, IGW, NAT GW, route tables, Flow Logs
    |   +-- main.tf
    |   +-- variables.tf
    |   +-- outputs.tf
    |   +-- versions.tf
    +-- compute/              # Compute: ALB, ASG, Launch Template, Security Groups, scaling policy
        +-- main.tf
        +-- variables.tf
        +-- outputs.tf
        +-- versions.tf
```

---

## Prerequisites

| Requirement | Minimum Version |
|---|---|
| [Terraform](https://developer.hashicorp.com/terraform/downloads) | >= 1.6.0 |
| [AWS Provider](https://registry.terraform.io/providers/hashicorp/aws) | ~> 5.0 |
| AWS credentials configured | - |

Recommended: use [tfenv](https://github.com/tfutils/tfenv) or [mise](https://mise.jdx.dev/) to pin the Terraform version per project.

---

## Modules

### VPC Module

**Path:** `modules/vpc`

Creates a complete, tiered VPC with all required networking primitives.

**Resources provisioned:**

| Resource | Description |
|---|---|
| `aws_vpc` | VPC with configurable CIDR, DNS hostnames, and DNS support |
| `aws_subnet` (x3 per AZ) | Public, private, and isolated DB subnets |
| `aws_internet_gateway` | Outbound internet access for public subnets |
| `aws_eip` + `aws_nat_gateway` | One per AZ (HA mode) or one shared (DR mode) |
| `aws_route_table` + associations | Separate tables for public, private (per AZ or shared), and DB tiers |
| `aws_flow_log` + CloudWatch | VPC Flow Logs with dedicated IAM role and policy |

### Compute Module

**Path:** `modules/compute`

Deploys a horizontally scalable application tier behind an internet-facing Application Load Balancer.

**Resources provisioned:**

| Resource | Description |
|---|---|
| `aws_security_group` (ALB + EC2) | Least-privilege ingress/egress rules |
| `aws_lb` | Internet-facing ALB with optional deletion protection |
| `aws_lb_target_group` | HTTP health checks with configurable path and thresholds |
| `aws_lb_listener` | HTTP:80 forwarding rule |
| `aws_launch_template` | AL2023 AMI (resolved dynamically), SSM + CloudWatch agents pre-installed |
| `aws_autoscaling_group` | Multi-AZ ASG with rolling instance refresh (>=50% healthy) |
| `aws_autoscaling_policy` | CPU target-tracking scaling policy |

---

## Usage

### 1. Instantiate the VPC module

```hcl
module "vpc_primary" {
  source = "./modules/vpc"

  name       = "myapp-us-east-1"
  vpc_cidr   = "10.0.0.0/16"
  az_count   = 3

  single_nat_gateway       = false   # HA: one NAT GW per AZ
  enable_flow_logs         = true
  flow_logs_retention_days = 30

  tags = {
    Environment = "production"
    Project     = "multi-region-migration"
  }
}
```

### 2. Instantiate the Compute module

```hcl
module "compute_primary" {
  source = "./modules/compute"

  name               = "myapp-us-east-1"
  vpc_id             = module.vpc_primary.vpc_id
  public_subnet_ids  = module.vpc_primary.public_subnet_ids
  private_subnet_ids = module.vpc_primary.private_subnet_ids

  instance_type    = "t3.small"
  min_size         = 2
  max_size         = 6
  desired_capacity = 2

  app_port           = 8080
  target_cpu_percent = 60

  tags = {
    Environment = "production"
    Project     = "multi-region-migration"
  }
}
```

### 3. Deploy the DR region

Repeat both module blocks with a second `aws` provider alias pointing at the DR region (e.g. `us-west-2`), using non-overlapping CIDRs (e.g. `10.1.0.0/16`) and `single_nat_gateway = true` to reduce standby costs.

---

## Inputs

### VPC Module

| Name | Description | Type | Default | Required |
|---|---|---|---|---|
| `name` | Name prefix applied to every resource | `string` | - | yes |
| `vpc_cidr` | CIDR block for the VPC (must not overlap with the other region) | `string` | - | yes |
| `az_count` | Number of Availability Zones to use (1-3) | `number` | `3` | no |
| `subnet_newbits` | Bits added to the VPC prefix to size each subnet | `number` | `4` | no |
| `single_nat_gateway` | `true` = single NAT GW (DR/cost); `false` = one per AZ (HA) | `bool` | `false` | no |
| `enable_dns_hostnames` | Assign public DNS hostnames to instances with public IPs | `bool` | `true` | no |
| `enable_dns_support` | Enable the Amazon-provided DNS resolver in the VPC | `bool` | `true` | no |
| `enable_flow_logs` | Stream VPC Flow Logs (ALL traffic) to a CloudWatch Logs group | `bool` | `true` | no |
| `flow_logs_retention_days` | Retention period for the Flow Logs CloudWatch log group | `number` | `30` | no |
| `tags` | Additional tags merged onto every resource | `map(string)` | `{}` | no |

### Compute Module

| Name | Description | Type | Default | Required |
|---|---|---|---|---|
| `name` | Name prefix for all resources (max 28 chars) | `string` | - | yes |
| `vpc_id` | ID of the VPC to deploy into | `string` | - | yes |
| `public_subnet_ids` | Public subnet IDs for the ALB (min 2 AZs) | `list(string)` | - | yes |
| `private_subnet_ids` | Private subnet IDs for the ASG launch template | `list(string)` | - | yes |
| `instance_type` | EC2 instance type | `string` | `"t3.micro"` | no |
| `key_name` | EC2 key pair name for SSH access | `string` | `null` | no |
| `min_size` | Minimum ASG capacity | `number` | `1` | no |
| `max_size` | Maximum ASG capacity | `number` | `3` | no |
| `desired_capacity` | Initial desired capacity | `number` | `2` | no |
| `app_port` | Port the application listens on inside EC2 | `number` | `8080` | no |
| `health_check_path` | HTTP path the ALB uses for target health checks | `string` | `"/"` | no |
| `health_check_healthy_threshold` | Consecutive successes to mark a target healthy | `number` | `2` | no |
| `health_check_unhealthy_threshold` | Consecutive failures to mark a target unhealthy | `number` | `3` | no |
| `health_check_grace_period` | ASG health check grace period (seconds) | `number` | `120` | no |
| `target_cpu_percent` | Target CPU utilisation (%) for the scaling policy | `number` | `60` | no |
| `enable_deletion_protection` | Prevent ALB deletion via the AWS API | `bool` | `true` | no |
| `tags` | Additional tags merged onto every resource | `map(string)` | `{}` | no |

---

## Outputs

### VPC Module

| Name | Description |
|---|---|
| `vpc_id` | ID of the VPC |
| `vpc_cidr_block` | CIDR block of the VPC (used by peering module for cross-region routes) |
| `availability_zones` | Ordered list of AZs used by this VPC |
| `public_subnet_ids` | Public subnet IDs - feed to ALB |
| `private_subnet_ids` | Private subnet IDs - feed to ASG |
| `db_subnet_ids` | Isolated DB subnet IDs - feed to RDS subnet group |

### Compute Module

| Name | Description |
|---|---|
| `alb_dns_name` | DNS name of the Application Load Balancer |
| `alb_arn` | ARN of the Application Load Balancer |
| `asg_name` | Name of the Auto Scaling Group |
| `target_group_arn` | ARN of the ALB target group |

---

## Design Decisions

**Non-overlapping CIDRs between regions.** The `vpc_cidr` variable description explicitly warns operators to use non-overlapping blocks, which is a prerequisite for VPC Peering or Transit Gateway attachment.

**Three-tier subnet layout.** Public, private, and DB subnets are computed automatically from the VPC CIDR using `cidrsubnet()`, ensuring tiers never overlap regardless of `az_count`.

**Single vs. per-AZ NAT Gateway.** Controlled by the `single_nat_gateway` flag. Primary regions use `false` (one per AZ) for AZ-fault tolerance; DR regions use `true` to minimise standby cost.

**DB subnets have no default route.** Database subnets use isolated route tables with no internet path, enforcing defence-in-depth even if a security group is misconfigured.

**Dynamic AMI resolution.** The compute module always resolves the latest AL2023 HVM x86_64 AMI owned by Amazon, eliminating stale AMI drift across regions and over time.

**Rolling instance refresh.** The ASG is configured with `instance_refresh { strategy = "Rolling" }` triggered by launch template changes, maintaining at least 50% healthy capacity during updates.

**Terraform drift prevention.** The ASG lifecycle block ignores `desired_capacity` after initial apply, so manual or Auto Scaling-driven capacity changes are not overwritten on the next `terraform apply`.

---

## Contributing

1. Fork the repository and create a feature branch: `git checkout -b feat/my-feature`
2. Commit changes following [Conventional Commits](https://www.conventionalcommits.org/): `git commit -m "feat: add RDS module"`
3. Push to your fork and open a Pull Request targeting `main`
4. Ensure `terraform fmt -recursive` and `terraform validate` pass before requesting review

---

## License

This project is licensed under the [MIT License](LICENSE).
