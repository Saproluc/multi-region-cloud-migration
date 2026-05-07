variable "primary_state_bucket" {
  description = <<-EOT
    S3 bucket name containing the primary env's Terraform state.
    Used by terraform_remote_state to read the source DB ARN for cross-region
    replica creation. Set this in terraform.tfvars after applying the primary env.
  EOT
  type        = string
  default     = "REPLACE_WITH_STATE_BUCKET"
}

variable "tags" {
  description = "Additional tags merged onto every resource in the DR environment."
  type        = map(string)
  default     = {}
}
