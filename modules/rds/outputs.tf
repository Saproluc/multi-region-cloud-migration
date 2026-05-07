output "db_instance_arn" {
  description = "ARN of the RDS instance. Pass to the DR env as replicate_source_db_arn."
  value       = aws_db_instance.this.arn
}

output "db_instance_endpoint" {
  description = "Connection endpoint in host:port format."
  value       = aws_db_instance.this.endpoint
}

output "db_instance_address" {
  description = "Hostname of the RDS instance (without port). Feed to the observability module."
  value       = aws_db_instance.this.address
}

output "db_instance_id" {
  description = "RDS instance identifier. Feed to the observability module for CloudWatch alarms."
  value       = aws_db_instance.this.identifier
}

output "secret_arn" {
  description = "Secrets Manager secret ARN holding master credentials. Null for read replicas."
  value       = local.is_replica ? null : aws_secretsmanager_secret.master[0].arn
}

output "security_group_id" {
  description = "RDS security group ID. Add extra ingress rules here for cross-VPC or VPN access."
  value       = aws_security_group.rds.id
}
