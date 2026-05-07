variable "name" {
  description = <<-EOT
    RDS instance identifier and name prefix for all associated resources.
    Must be lowercase alphanumeric + hyphens, 1–63 characters.
  EOT
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,61}[a-z0-9]$", var.name))
    error_message = "name must start with a letter, contain only lowercase letters, numbers, and hyphens, and be 2–63 characters."
  }
}

variable "vpc_id" {
  description = "VPC ID from the vpc module."
  type        = string
}

variable "db_subnet_ids" {
  description = "DB-tier subnet IDs from the vpc module. The module creates the DB subnet group from these."
  type        = list(string)

  validation {
    condition     = length(var.db_subnet_ids) >= 2
    error_message = "RDS Multi-AZ and subnet groups require at least two subnets in different AZs."
  }
}

variable "app_security_group_id" {
  description = "EC2 security group ID from the compute module. Granted Postgres (5432) access to this DB."
  type        = string
}

# ── Engine ────────────────────────────────────────────────────────────────────

variable "engine_version" {
  description = "Postgres engine version. Must be a valid RDS Postgres version string."
  type        = string
  default     = "16.3"
}

variable "instance_class" {
  description = "RDS instance class."
  type        = string
  default     = "db.t3.medium"
}

# ── Primary credentials (ignored when creating a replica) ─────────────────────

variable "db_name" {
  description = "Name of the initial database. Not used when replicate_source_db_arn is set."
  type        = string
  default     = "appdb"
}

variable "db_username" {
  description = "Master username. Not used when replicate_source_db_arn is set."
  type        = string
  default     = "dbadmin"
}

# ── Storage ───────────────────────────────────────────────────────────────────

variable "allocated_storage" {
  description = "Initial allocated storage in GiB."
  type        = number
  default     = 100
}

variable "max_allocated_storage" {
  description = "Upper bound for RDS storage autoscaling in GiB. Set equal to allocated_storage to disable."
  type        = number
  default     = 500
}

variable "kms_key_arn" {
  description = "Customer-managed KMS key ARN for storage encryption. Uses the aws/rds managed key when empty."
  type        = string
  default     = ""
}

# ── Availability ──────────────────────────────────────────────────────────────

variable "multi_az" {
  description = "Deploy a standby replica in a second AZ. Set true for primary, false for DR replica."
  type        = bool
  default     = true
}

# ── Backup ────────────────────────────────────────────────────────────────────

variable "backup_retention_period" {
  description = "Days to retain automated backups. 7 for primary, 1 for DR replica."
  type        = number
  default     = 7

  validation {
    condition     = var.backup_retention_period >= 0 && var.backup_retention_period <= 35
    error_message = "backup_retention_period must be between 0 and 35 days."
  }
}

variable "backup_window" {
  description = "Daily backup window in UTC (hh24:mi-hh24:mi). Must not overlap maintenance_window."
  type        = string
  default     = "03:00-04:00"
}

variable "maintenance_window" {
  description = "Weekly maintenance window (ddd:hh24:mi-ddd:hh24:mi UTC)."
  type        = string
  default     = "Mon:04:00-Mon:05:00"
}

# ── Lifecycle ─────────────────────────────────────────────────────────────────

variable "deletion_protection" {
  description = "Prevent accidental deletion via the AWS API. Disable for DR or dev environments."
  type        = bool
  default     = true
}

variable "skip_final_snapshot" {
  description = "Skip the final snapshot on destroy. Set true for DR replica (primary holds the authoritative backup)."
  type        = bool
  default     = false
}

# ── Monitoring ────────────────────────────────────────────────────────────────

variable "performance_insights_enabled" {
  description = "Enable Performance Insights for query-level diagnostics."
  type        = bool
  default     = true
}

variable "performance_insights_retention_period" {
  description = "Retention period for Performance Insights data in days. Must be 7 or a multiple of 31."
  type        = number
  default     = 7

  validation {
    condition     = var.performance_insights_retention_period == 7 || var.performance_insights_retention_period % 31 == 0
    error_message = "performance_insights_retention_period must be 7 or a multiple of 31 (31, 62, 93…)."
  }
}

variable "monitoring_interval" {
  description = "Enhanced monitoring granularity in seconds. 0 disables enhanced monitoring."
  type        = number
  default     = 60

  validation {
    condition     = contains([0, 1, 5, 10, 15, 30, 60], var.monitoring_interval)
    error_message = "monitoring_interval must be one of: 0, 1, 5, 10, 15, 30, 60."
  }
}

# ── Replica ───────────────────────────────────────────────────────────────────

variable "replicate_source_db_arn" {
  description = <<-EOT
    ARN of the source RDS instance for cross-region read replica creation.
    When set, this module creates a replica instead of a primary:
    - Master password and Secrets Manager secret are skipped.
    - db_name, db_username, and backup config are inherited from the source.
  EOT
  type        = string
  default     = ""
}

# ── Secrets Manager ───────────────────────────────────────────────────────────

variable "secret_recovery_window_days" {
  description = "Days before Secrets Manager permanently deletes a secret after destroy. Set 0 for immediate deletion in dev/test."
  type        = number
  default     = 7
}

variable "tags" {
  description = "Additional tags merged onto every resource."
  type        = map(string)
  default     = {}
}
