
provider "aws" {
  region = "ca-central-1"
}

locals {
  //Put all common tags here
  common_tags = {
    Project = "SAML Login Provider"
    Environment = "Development"
  }
   
}