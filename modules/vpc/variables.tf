variable "name" {
  description = "Name prefix applied to every resource in this module."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC. Must not overlap with the other region's VPC."
  type        = string

  validation {
    condition     = can(cidrnetmask(var.vpc_cidr))
    error_message = "vpc_cidr must be a valid CIDR block (e.g. 10.0.0.0/16)."
  }
}

variable "az_count" {
  description = "Number of availability zones to use. Subnets are carved per AZ across all three tiers."
  type        = number
  default     = 3

  validation {
    condition     = var.az_count >= 1 && var.az_count <= 3
    error_message = "az_count must be 1, 2, or 3."
  }
}

variable "subnet_newbits" {
  description = <<-EOT
    Bits added to the VPC prefix to size each subnet.
    Example: vpc_cidr=/16, subnet_newbits=4 → nine /20 subnets (3 tiers × 3 AZs).
    Ensure the VPC prefix + newbits leaves enough space for az_count * 3 blocks.
  EOT
  type        = number
  default     = 4

  validation {
    condition     = var.subnet_newbits >= 2 && var.subnet_newbits <= 8
    error_message = "subnet_newbits must be between 2 and 8."
  }
}

variable "single_nat_gateway" {
  description = <<-EOT
    When true, a single NAT Gateway is created in az[0] and all private subnets
    share it. Set to true for the DR region to reduce standby costs.
    When false (default), one NAT Gateway is provisioned per AZ for HA.
  EOT
  type        = bool
  default     = false
}

variable "enable_dns_hostnames" {
  description = "Assign public DNS hostnames to instances with public IPs."
  type        = bool
  default     = true
}

variable "enable_dns_support" {
  description = "Enable the Amazon-provided DNS resolver in the VPC."
  type        = bool
  default     = true
}

variable "enable_flow_logs" {
  description = "Stream VPC Flow Logs (ALL traffic) to a CloudWatch Logs group."
  type        = bool
  default     = true
}

variable "flow_logs_retention_days" {
  description = "Retention period for the VPC Flow Logs CloudWatch log group."
  type        = number
  default     = 30
}

variable "tags" {
  description = "Additional tags merged onto every resource."
  type        = map(string)
  default     = {}
}
