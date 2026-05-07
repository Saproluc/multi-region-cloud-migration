locals {
  # Drives count on every primary-only resource (password, secret, subnet group).
  is_replica  = var.replicate_source_db_arn != ""
  common_tags = merge(var.tags, { ManagedBy = "terraform" })
}

# ── Enhanced Monitoring IAM ───────────────────────────────────────────────────
# RDS pushes OS-level metrics every monitoring_interval seconds via this role.

data "aws_iam_policy_document" "enhanced_monitoring_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["monitoring.rds.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "enhanced_monitoring" {
  name               = "${var.name}-rds-enhanced-monitoring"
  assume_role_policy = data.aws_iam_policy_document.enhanced_monitoring_assume.json
  description        = "Allows RDS Enhanced Monitoring to publish metrics to CloudWatch for ${var.name}."

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "enhanced_monitoring" {
  role       = aws_iam_role.enhanced_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# ── Security Group ────────────────────────────────────────────────────────────

resource "aws_security_group" "rds" {
  name_prefix = "${var.name}-rds-"
  vpc_id      = var.vpc_id
  description = "Allows Postgres (5432) only from the app-tier EC2 security group."

  tags = merge(local.common_tags, { Name = "${var.name}-rds-sg" })

  lifecycle {
    create_before_destroy = true
  }
}

# Ingress locked to the app SG — no direct internet or VPN path to the DB
resource "aws_vpc_security_group_ingress_rule" "rds_from_app" {
  security_group_id            = aws_security_group.rds.id
  description                  = "Postgres from app tier"
  referenced_security_group_id = var.app_security_group_id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
}

# ── DB Subnet Group ───────────────────────────────────────────────────────────

resource "aws_db_subnet_group" "this" {
  name_prefix = "${var.name}-"
  subnet_ids  = var.db_subnet_ids
  description = "Subnet group for ${var.name} — spans all DB-tier subnets in the VPC."

  tags = merge(local.common_tags, { Name = "${var.name}-db-subnet-group" })
}

# ── Parameter Group ───────────────────────────────────────────────────────────

resource "aws_db_parameter_group" "this" {
  name_prefix = "${var.name}-"
  family      = "postgres16"
  description = "Custom parameter group for ${var.name} Postgres 16."

  # Capture connection/disconnection events for audit trails
  parameter {
    name  = "log_connections"
    value = "1"
  }

  parameter {
    name  = "log_disconnections"
    value = "1"
  }

  tags = local.common_tags

  lifecycle {
    create_before_destroy = true
  }
}

# ── Master Password + Secrets Manager (primary only) ─────────────────────────
# Replicas inherit credentials from the source — no separate secret needed.

resource "random_password" "master" {
  count = local.is_replica ? 0 : 1

  length  = 32
  special = true
  # Exclude characters that break connection strings or shell interpolation
  override_special = "!#$%&*-_=+?"
}

resource "aws_secretsmanager_secret" "master" {
  count = local.is_replica ? 0 : 1

  name                    = "${var.name}-rds-master"
  description             = "Master credentials for RDS instance ${var.name}."
  recovery_window_in_days = var.secret_recovery_window_days

  tags = local.common_tags
}

# ── RDS Instance ──────────────────────────────────────────────────────────────

resource "aws_db_instance" "this" {
  identifier = var.name

  # Engine — specified explicitly on replicas too (required for cross-region)
  engine         = "postgres"
  engine_version = var.engine_version

  instance_class = var.instance_class

  # Storage: gp3, encrypted, autoscaling up to max_allocated_storage
  storage_type          = "gp3"
  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_encrypted     = true
  kms_key_id            = var.kms_key_arn != "" ? var.kms_key_arn : null

  # Primary-only fields — null is correctly omitted by the provider when replica
  db_name  = local.is_replica ? null : var.db_name
  username = local.is_replica ? null : var.db_username
  password = local.is_replica ? null : random_password.master[0].result

  # Cross-region replica source; null for primaries
  replicate_source_db = local.is_replica ? var.replicate_source_db_arn : null

  # Network
  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  multi_az               = var.multi_az
  publicly_accessible    = false

  parameter_group_name = aws_db_parameter_group.this.name

  # Backup
  backup_retention_period = var.backup_retention_period
  backup_window           = var.backup_window
  maintenance_window      = var.maintenance_window
  copy_tags_to_snapshot   = true

  # Performance Insights — retention must be 7 or multiple of 31
  performance_insights_enabled          = var.performance_insights_enabled
  performance_insights_retention_period = var.performance_insights_enabled ? var.performance_insights_retention_period : null

  # Enhanced Monitoring — IAM role must exist before the instance is created
  monitoring_interval = var.monitoring_interval
  monitoring_role_arn = var.monitoring_interval > 0 ? aws_iam_role.enhanced_monitoring.arn : null

  # CloudWatch log exports — forwarded to /aws/rds/instance/<id>/postgresql etc.
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  auto_minor_version_upgrade = true
  apply_immediately          = false
  deletion_protection        = var.deletion_protection
  skip_final_snapshot        = var.skip_final_snapshot
  final_snapshot_identifier  = var.skip_final_snapshot ? null : "${var.name}-final-snapshot"

  tags = merge(local.common_tags, { Name = var.name })

  # Policy attachment must be complete before RDS attempts to use the role
  depends_on = [aws_iam_role_policy_attachment.enhanced_monitoring]
}

# ── Secret Version ────────────────────────────────────────────────────────────
# Written after the DB is created so the endpoint is available.
# Stored in the standard RDS Secrets Manager format recognised by most SDKs.

resource "aws_secretsmanager_secret_version" "master" {
  count = local.is_replica ? 0 : 1

  secret_id = aws_secretsmanager_secret.master[0].id
  secret_string = jsonencode({
    engine   = "postgres"
    host     = aws_db_instance.this.address
    port     = aws_db_instance.this.port
    dbname   = var.db_name
    username = var.db_username
    password = random_password.master[0].result
  })
}
