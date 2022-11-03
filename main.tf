# Configure the AWS Provider
// set up a default region to work around bug that prompts for region otherwise :(
provider "aws" {
  region = "ca-central-1"
}

provider "aws" {
  region = "ca-central-1"
  alias  = "root-account"
}

provider "aws" {
  region = "ca-central-1"
  alias  = "iam-security-account"

  assume_role {
    role_arn     = "arn:aws:iam::${local.iam_security_account.id}:role/AWSCloudFormationStackSetExecutionRole"
    session_name = "slz-terraform-automation"
  }
}

module "lz_info" {
  source = "github.com/BCDevOps/terraform-aws-sea-organization-info"
  providers = {
    aws = aws.root-account
  }
}

data "aws_caller_identity" "master_account_caller" {
  provider = aws.root-account
}


locals {
  core_accounts        = { for account in module.lz_info.core_accounts : account.name => account }
  iam_security_account = local.core_accounts["iam-security"]
  saml_destination_url = "https://${aws_cloudfront_distribution.geofencing.domain_name}/${aws_api_gateway_deployment.samlpost.stage_name}"


  //Put all common tags here
  common_tags = {
    Project     = "SAML Login Provider"
    Environment = "Development"
  }

  # This is needed by the lambda code so it knows what role to assume to read org metadata, but can be replaced by ${aws_iam_role.saml_read_role.name} once we have the role creation in TF working
  saml_read_role_name = "BCGOV_SAML_Organizations_Read_Role"

  master_account_id = data.aws_caller_identity.master_account_caller.account_id
}

resource "aws_iam_role" "saml_read_role" {
  provider = aws.root-account
  name     = local.saml_read_role_name

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::${local.master_account_id}:saml-provider/${var.keycloak_saml_name}"
      },
      "Action": "sts:AssumeRoleWithSAML",
      "Condition": {
        "StringEquals": {
          "SAML:aud": "${local.saml_destination_url}"
        }
      }
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "saml_read_role_policy" {
  provider = aws.root-account

  name = "saml_user_account_readpolicy"
  role = aws_iam_role.saml_read_role.id

  policy = <<-EOF
  {
      "Version": "2012-10-17",
      "Statement": [
          {
              "Effect": "Allow",
              "Action": [
                "organizations:ListTagsForResource",
				"organizations:DescribeAccount"
            ],
            "Resource": [
                "*"
            ]
          }
      ]
  }
EOF
}
