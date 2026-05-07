output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.this.id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC. Used by the peering module to add cross-region routes."
  value       = aws_vpc.this.cidr_block
}

output "availability_zones" {
  description = "Ordered list of AZs used by this VPC."
  value       = local.azs
}

# ── Subnet IDs ────────────────────────────────────────────────────────────────

output "public_subnet_ids" {
  description = "Public subnet IDs (one per AZ). Feed to ALB."
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Private subnet IDs (one per AZ). Feed to ASG launch template."
  value       = aws_subnet.private[*].id
}

output "db_subnet_ids" {
  description = "DB subnet IDs (one per AZ). Feed to RDS subnet group."
  value       = aws_subnet.db[*].id
}

# ── Subnet CIDRs ──────────────────────────────────────────────────────────────

output "public_subnet_cidrs" {
  description = "CIDR blocks of public subnets."
  value       = aws_subnet.public[*].cidr_block
}

output "private_subnet_cidrs" {
  description = "CIDR blocks of private subnets."
  value       = aws_subnet.private[*].cidr_block
}

output "db_subnet_cidrs" {
  description = "CIDR blocks of DB subnets."
  value       = aws_subnet.db[*].cidr_block
}

# ── Gateways ──────────────────────────────────────────────────────────────────

output "igw_id" {
  description = "ID of the Internet Gateway."
  value       = aws_internet_gateway.this.id
}

output "nat_gateway_ids" {
  description = "IDs of NAT Gateways (length=1 in single-NAT mode, az_count in HA mode)."
  value       = aws_nat_gateway.this[*].id
}

output "nat_public_ips" {
  description = "Elastic IPs attached to the NAT Gateways. Allowlist these on external services."
  value       = aws_eip.nat[*].public_ip
}

# ── Route Tables ──────────────────────────────────────────────────────────────

output "public_route_table_id" {
  description = "ID of the shared public route table."
  value       = aws_route_table.public.id
}

output "private_route_table_ids" {
  description = "IDs of private route tables. The peering module adds cross-region routes here."
  value       = aws_route_table.private[*].id
}

output "db_route_table_ids" {
  description = "IDs of the isolated DB route tables."
  value       = aws_route_table.db[*].id
}

# ── Flow Logs ─────────────────────────────────────────────────────────────────

output "flow_log_group_name" {
  description = "CloudWatch log group receiving VPC Flow Logs. Empty string when disabled."
  value       = var.enable_flow_logs ? aws_cloudwatch_log_group.flow_logs[0].name : ""
}
