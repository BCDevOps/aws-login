
provider "aws" {
  region = "ca-central-1"
}

locals {
  //Put all common tags here
  common_tags = {
    Project = "SAML Login Provider"
    Environment = "Development"
  }
   
  saml_read_role_name = "BCGOV_SAML_Organizations_Read_Role" # This is referenced in the master_account_read_role.yaml
}