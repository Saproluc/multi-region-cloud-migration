# Populate bucket/dynamodb_table after running the bootstrap env.
# These values cannot reference Terraform variables — edit them directly.
terraform {
  backend "s3" {
    bucket         = "REPLACE_WITH_STATE_BUCKET"
    key            = "primary/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "REPLACE_WITH_LOCK_TABLE"
    encrypt        = true
  }
}
