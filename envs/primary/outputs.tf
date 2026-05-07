output "vpc_id" {
  description = "Primary VPC ID."
  value       = module.vpc.vpc_id
}

output "nat_public_ips" {
  description = "EIPs of the primary NAT gateways. Allowlist on external dependencies."
  value       = module.vpc.nat_public_ips
}

output "alb_dns_name" {
  description = "DNS name of the primary ALB. Register in Route 53 as the active origin."
  value       = module.compute.alb_dns_name
}

output "alb_zone_id" {
  description = "Hosted zone ID of the primary ALB. Required for Route 53 alias records."
  value       = module.compute.alb_zone_id
}

output "asg_name" {
  description = "Primary ASG name. Feed to the observability module."
  value       = module.compute.asg_name
}

output "db_instance_arn" {
  description = "Primary DB ARN. Referenced by the DR env as replicate_source_db_arn."
  value       = module.rds.db_instance_arn
}

output "db_instance_id" {
  description = "Primary DB instance identifier. Feed to the observability module."
  value       = module.rds.db_instance_id
}

output "db_instance_endpoint" {
  description = "Primary DB connection endpoint."
  value       = module.rds.db_instance_endpoint
}

output "secret_arn" {
  description = "Secrets Manager ARN holding the primary DB master credentials."
  value       = module.rds.secret_arn
}
