
provider "aws" {
  region = "ca-central-1"
}

locals {
  //Put all common tags here
  common_tags = {
    Project = "SAML Login Provider"
    Environment = "Development"
  }
  lambda_read_role_arn = "arn:aws:iam::${var.master_account_id}:role/BCGOV_Lambda_Organizations_Read_Role" # This is referenced in the master_account_read_role.yaml
  saml_read_role_name = "BCGOV_SAML_Organizations_Read_Role" # This is referenced in the master_account_read_role.yaml
}

output "master_account" {
  value = var.master_account_id
}