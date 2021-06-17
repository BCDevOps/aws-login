resource "aws_api_gateway_rest_api" "samlpost" {
  provider = aws.iam-security-account

  name        = "SAMLPostExample"
  description = "Terraform Serverless Application Example"

  tags = local.common_tags
}

resource "aws_api_gateway_resource" "proxy" {
  provider = aws.iam-security-account

  rest_api_id = aws_api_gateway_rest_api.samlpost.id
  parent_id   = aws_api_gateway_rest_api.samlpost.root_resource_id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "proxy" {
  provider = aws.iam-security-account

  rest_api_id   = aws_api_gateway_rest_api.samlpost.id
  resource_id   = aws_api_gateway_resource.proxy.id
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda" {
  provider = aws.iam-security-account

  rest_api_id = aws_api_gateway_rest_api.samlpost.id
  resource_id = aws_api_gateway_method.proxy.resource_id
  http_method = aws_api_gateway_method.proxy.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.samlpost.invoke_arn
}

resource "aws_api_gateway_method" "proxy_root" {
  provider = aws.iam-security-account

  rest_api_id   = aws_api_gateway_rest_api.samlpost.id
  resource_id   = aws_api_gateway_rest_api.samlpost.root_resource_id
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda_root" {
  provider = aws.iam-security-account

  rest_api_id = aws_api_gateway_rest_api.samlpost.id
  resource_id = aws_api_gateway_method.proxy_root.resource_id
  http_method = aws_api_gateway_method.proxy_root.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.samlpost.invoke_arn
}

resource "aws_api_gateway_deployment" "samlpost" {
  provider = aws.iam-security-account

  depends_on = [
    aws_api_gateway_integration.lambda,
    aws_api_gateway_integration.lambda_root,
  ]

  rest_api_id = aws_api_gateway_rest_api.samlpost.id
  //	@todo change value below to something like "saml"
  stage_name = "test"
}


output "base_url" {
  value = aws_api_gateway_deployment.samlpost.invoke_url
}


