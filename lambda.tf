data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/samlpost"
  output_path = "${path.module}/dist/lambda_samlpost.zip"
}

resource "aws_lambda_function" "samlpost" {
  provider = aws.iam-security-account

  function_name = "${var.lambda_name}-${var.resource_name_suffix}"
  filename      = data.archive_file.lambda_zip.output_path

  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  //	source_code_hash = filebase64sha256(data.archive_file.lambda_zip.output_path)

  handler = "index.handler"
  runtime = "nodejs14.x"
  timeout = 10

  role = aws_iam_role.lambda_exec.arn

  environment {
    variables = {
      samlReadRole                    = "arn:aws:iam::${local.master_account_id}:saml-provider/${var.keycloak_saml_name},arn:aws:iam::${local.master_account_id}:role/${local.saml_read_role_name}",
      kc_base_url                     = var.kc_base_url,
      kc_realm                        = var.kc_realm,
      kc_terraform_auth_client_id     = var.kc_terraform_auth_client_id,
      kc_terraform_auth_client_secret = var.kc_terraform_auth_client_secret
    }
  }

  tags = local.common_tags
}

resource "aws_iam_role" "lambda_exec" {
  provider = aws.iam-security-account

  name               = "${var.lambda_name}-${var.resource_name_suffix}"
  assume_role_policy = <<EOF
{
   "Version": "2012-10-17",
   "Statement": [
     {
       "Action": "sts:AssumeRole",
       "Principal": {
         "Service": "lambda.amazonaws.com"
       },
       "Effect": "Allow"
     }
   ]
 }
 EOF

  tags = local.common_tags
}


data "aws_iam_policy" "AWSLambdaBasicExecutionRole" {
  arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "test-attach" {
  provider = aws.iam-security-account

  role       = aws_iam_role.lambda_exec.name
  policy_arn = data.aws_iam_policy.AWSLambdaBasicExecutionRole.arn
}

resource "aws_iam_policy" "assume_role_org_read" {
  provider = aws.iam-security-account
  name     = "serverless_saml_lambda-org-read-${var.resource_name_suffix}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "sts:AssumeRole"
      ]
      Resource = "${aws_iam_role.saml_read_role.arn}"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "thisSTS" {
  provider   = aws.iam-security-account
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.assume_role_org_read.arn
}

resource "aws_lambda_permission" "apigw" {
  provider = aws.iam-security-account

  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.samlpost.function_name
  principal     = "apigateway.amazonaws.com"

  # The "/*/*" portion grants access from any method on any resource
  # within the API Gateway REST API.
  source_arn = "${aws_api_gateway_rest_api.samlpost.execution_arn}/*/*"
}
