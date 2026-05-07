variable "tags" {
  description = "Additional tags merged onto every resource in the primary environment."
  type        = map(string)
  default     = {}
}
