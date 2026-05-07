# Populate bucket/dynamodb_table after running the bootstrap env.
# These values cannot reference Terraform variables — edit them directly.
terraform {
  backend "s3" {
    bucket         = "REPLACE_WITH_STATE_BUCKET"
    key            = "dr/terraform.tfstate"
    region         = "us-west-2"
    dynamodb_table = "REPLACE_WITH_LOCK_TABLE"
    encrypt        = true
  }
}
