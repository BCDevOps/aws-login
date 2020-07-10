
resource "aws_lambda_function" "samlpost" {
  function_name = "SAMLPostExample"
  filename      = "../../dist/lambda_samlpost.zip"

  source_code_hash = filebase64sha256("../../dist/lambda_samlpost.zip")

  handler = "index.handler"
  runtime = "nodejs12.x"

  role = aws_iam_role.lambda_exec.arn

   environment {
    variables = {
      lambdaReadRole = local.lambda_read_role_arn
      samlReadRole = "arn:aws:iam::${var.master_account_id}:saml-provider/${var.keycloak_saml_name},arn:aws:iam::${var.master_account_id}:role/${local.saml_read_role_name}"
    }
  }

  tags = local.common_tags
}

resource "aws_iam_role" "lambda_exec" {
  name               = "serverless_saml_lambda"
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


resource "aws_iam_role_policy" "lambda_exec_org_policy" {
  name = "serverless_saml_lambda_read_orgs"
  role = aws_iam_role.lambda_exec.id

  policy = <<-EOF
  {
      "Version": "2012-10-17",
      "Statement": [
          {
              "Effect": "Allow",
              "Action": [
                  "logs:CreateLogGroup",
                  "logs:CreateLogStream",
                  "logs:PutLogEvents",
                  "logs:DescribeLogStreams"
              ],
              "Resource": [
                  "arn:aws:logs:*:*:*"
              ]
          },
          {
              "Effect": "Allow",
              "Action": "sts:AssumeRole",
              "Resource": "arn:aws:iam::${var.master_account_id}:role/BCGOV_Lambda_Organizations_Read_Role"
          }
      ]
  }
EOF
}





data "aws_iam_policy" "AWSLambdaBasicExecutionRole" {
  arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "test-attach" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = data.aws_iam_policy.AWSLambdaBasicExecutionRole.arn
}

resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.samlpost.function_name
  principal     = "apigateway.amazonaws.com"

  # The "/*/*" portion grants access from any method on any resource
  # within the API Gateway REST API.
  source_arn = "${aws_api_gateway_rest_api.samlpost.execution_arn}/*/*"
}


output "lambda_role_arn" {
  value =  aws_iam_role.lambda_exec.arn
}