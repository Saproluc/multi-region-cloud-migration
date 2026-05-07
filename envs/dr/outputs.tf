output "vpc_id" {
  description = "DR VPC ID."
  value       = module.vpc.vpc_id
}

output "nat_public_ips" {
  description = "EIP of the DR NAT gateway (single-NAT mode)."
  value       = module.vpc.nat_public_ips
}

output "alb_dns_name" {
  description = "DNS name of the DR ALB. Register in Route 53 as the failover origin."
  value       = module.compute.alb_dns_name
}

output "alb_zone_id" {
  description = "Hosted zone ID of the DR ALB. Required for Route 53 alias records."
  value       = module.compute.alb_zone_id
}

output "asg_name" {
  description = "DR ASG name. Feed to the observability module."
  value       = module.compute.asg_name
}

output "db_instance_arn" {
  description = "DR replica DB ARN."
  value       = module.rds.db_instance_arn
}

output "db_instance_id" {
  description = "DR replica DB instance identifier. Feed to the observability module."
  value       = module.rds.db_instance_id
}

output "db_instance_endpoint" {
  description = "DR replica DB connection endpoint."
  value       = module.rds.db_instance_endpoint
}
