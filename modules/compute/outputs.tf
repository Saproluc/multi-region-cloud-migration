# ── ALB ───────────────────────────────────────────────────────────────────────

output "alb_arn" {
  description = "ARN of the Application Load Balancer."
  value       = aws_lb.this.arn
}

output "alb_arn_suffix" {
  description = "ARN suffix used in CloudWatch metrics (e.g. app/name/id). Feed to the observability module."
  value       = aws_lb.this.arn_suffix
}

output "alb_dns_name" {
  description = "DNS name of the ALB. Feed to the dns module as the failover origin."
  value       = aws_lb.this.dns_name
}

output "alb_zone_id" {
  description = "Hosted zone ID of the ALB. Required for Route 53 alias records."
  value       = aws_lb.this.zone_id
}

# ── Target Group ──────────────────────────────────────────────────────────────

output "target_group_arn" {
  description = "ARN of the target group."
  value       = aws_lb_target_group.this.arn
}

output "target_group_arn_suffix" {
  description = "ARN suffix used in CloudWatch metrics for the target group."
  value       = aws_lb_target_group.this.arn_suffix
}

# ── ASG ───────────────────────────────────────────────────────────────────────

output "asg_name" {
  description = "Name of the Auto Scaling Group. Feed to the observability module for alarms."
  value       = aws_autoscaling_group.this.name
}

output "asg_arn" {
  description = "ARN of the Auto Scaling Group."
  value       = aws_autoscaling_group.this.arn
}

# ── Launch Template ───────────────────────────────────────────────────────────

output "launch_template_id" {
  description = "ID of the launch template."
  value       = aws_launch_template.this.id
}

output "launch_template_latest_version" {
  description = "Latest version number of the launch template."
  value       = aws_launch_template.this.latest_version
}

output "ami_id" {
  description = "AL2023 AMI ID resolved at apply time for this region."
  value       = data.aws_ami.al2023.id
}

# ── Security Groups ───────────────────────────────────────────────────────────

output "alb_security_group_id" {
  description = "Security group ID of the ALB. Reference from other modules that need to allow ALB egress."
  value       = aws_security_group.alb.id
}

output "ec2_security_group_id" {
  description = "Security group ID of the EC2 instances. Add peering/RDS ingress rules against this."
  value       = aws_security_group.ec2.id
}

# ── IAM ───────────────────────────────────────────────────────────────────────

output "ec2_iam_role_arn" {
  description = "ARN of the EC2 instance IAM role."
  value       = aws_iam_role.ec2.arn
}

output "ec2_iam_role_name" {
  description = "Name of the EC2 instance IAM role."
  value       = aws_iam_role.ec2.name
}
