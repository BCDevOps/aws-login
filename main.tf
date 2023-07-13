module "lz_info" {
  source = "github.com/BCDevOps/terraform-aws-sea-organization-info"
  providers = {
    aws = aws.master-account
  }
}

data "aws_caller_identity" "master_account_caller" {
  provider = aws.master-account
}


locals {
  core_accounts          = { for account in module.lz_info.core_accounts : account.name => account }
  iam_security_account   = local.core_accounts["iam-security"]
  perimeter_account      = local.core_accounts["Perimeter"]
  saml_destination_url   = "https://login.${var.domain_name}/${aws_api_gateway_deployment.samlpost.stage_name}"


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
  provider = aws.master-account
  name     = local.saml_read_role_name

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::${local.iam_security_account.id}:role/${var.lambda_name}-${var.resource_name_suffix}"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "saml_read_role_policy" {
  provider = aws.master-account

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