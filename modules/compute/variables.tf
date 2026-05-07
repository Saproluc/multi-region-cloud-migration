variable "name" {
  description = <<-EOT
    Name prefix for all resources. Must be ≤ 28 characters — ALB names are
    capped at 32 and this module appends up to 4 characters as a suffix.
  EOT
  type        = string

  validation {
    condition     = length(var.name) <= 28
    error_message = "name must be 28 characters or fewer (ALB name limit is 32, suffix '-alb' is appended)."
  }
}

variable "vpc_id" {
  description = "ID of the VPC to deploy into."
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for the ALB (one per AZ, min 2)."
  type        = list(string)

  validation {
    condition     = length(var.public_subnet_ids) >= 2
    error_message = "ALB requires subnets in at least two AZs."
  }
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for the ASG launch template."
  type        = list(string)
}

# ── Instance ──────────────────────────────────────────────────────────────────

variable "instance_type" {
  description = "EC2 instance type."
  type        = string
  default     = "t3.micro"
}

variable "root_volume_size" {
  description = "Root EBS volume size in GiB."
  type        = number
  default     = 20
}

variable "user_data" {
  description = <<-EOT
    Base64-encoded user data script. When empty (default) the module installs
    and starts the CloudWatch agent on Amazon Linux 2023.
  EOT
  type        = string
  default     = ""
}

# ── ASG ───────────────────────────────────────────────────────────────────────

variable "min_size" {
  description = "Minimum number of EC2 instances in the ASG."
  type        = number
  default     = 1
}

variable "max_size" {
  description = "Maximum number of EC2 instances in the ASG."
  type        = number
  default     = 4
}

variable "desired_capacity" {
  description = "Initial desired capacity. Ignored after first apply (ASG manages it)."
  type        = number
  default     = 2
}

variable "health_check_grace_period" {
  description = "Seconds ASG waits after launch before checking instance health."
  type        = number
  default     = 300
}

# ── Scaling policy ────────────────────────────────────────────────────────────

variable "target_cpu_percent" {
  description = "Target CPU utilization (%) for the ASG target-tracking policy."
  type        = number
  default     = 60

  validation {
    condition     = var.target_cpu_percent > 0 && var.target_cpu_percent < 100
    error_message = "target_cpu_percent must be between 1 and 99."
  }
}

# ── ALB / Target Group ────────────────────────────────────────────────────────

variable "app_port" {
  description = "Port the application listens on inside EC2 (target group port)."
  type        = number
  default     = 8080
}

variable "health_check_path" {
  description = "HTTP path the ALB uses for target health checks."
  type        = string
  default     = "/"
}

variable "health_check_healthy_threshold" {
  description = "Consecutive successes required to mark a target healthy."
  type        = number
  default     = 2
}

variable "health_check_unhealthy_threshold" {
  description = "Consecutive failures required to mark a target unhealthy."
  type        = number
  default     = 3
}

variable "enable_deletion_protection" {
  description = "Prevent the ALB from being deleted via the AWS API. Disable in DR / dev."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Additional tags merged onto every resource."
  type        = map(string)
  default     = {}
}
