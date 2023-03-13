locals {
  cf_origin_id = "api_gateway_saml"
}

data "aws_route53_zone" "this" {
  provider = aws.perimeter-account
  name     = var.domain_name
}

resource "aws_route53_record" "login_app" {
  provider = aws.perimeter-account
  zone_id  = data.aws_route53_zone.this.zone_id
  name     = "login.${var.domain_name}"
  type     = "A"

  alias {
    name                   = aws_cloudfront_distribution.geofencing.domain_name
    zone_id                = aws_cloudfront_distribution.geofencing.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_acm_certificate" "this" {
  provider          = aws.iam-security-account-us-east-1
  domain_name       = "login.${var.domain_name}"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "this_acm" {
  provider = aws.perimeter-account
  for_each = {
    for dvo in aws_acm_certificate.this.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.this.zone_id
}

resource "aws_acm_certificate_validation" "this" {
  provider                = aws.iam-security-account-us-east-1
  certificate_arn         = aws_acm_certificate.this.arn
  validation_record_fqdns = [for record in aws_route53_record.this_acm : record.fqdn]
}

resource "aws_cloudfront_distribution" "geofencing" {
  provider = aws.iam-security-account

  depends_on = [
  aws_api_gateway_deployment.samlpost]
  origin {
    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols = [
      "TLSv1.2"]
    }

    domain_name = trimsuffix(trimprefix(aws_api_gateway_deployment.samlpost.invoke_url, "https://"), "/${aws_api_gateway_deployment.samlpost.stage_name}")
    origin_id   = local.cf_origin_id

  }

  enabled         = true
  is_ipv6_enabled = true
  comment         = "geofencing"

  //	- logging should probably be in a central location (centralized-logging account?) - in an aggregated/shared bucket and perhaps also synced into a bucket within the account where the aws-login app is deployed
  //	- prefix should follow SEA convention like <account>/<region>/<service name> eg. 12345678/ca-central-1/cloudfront
  //
  //  logging_config {
  //    include_cookies = false
  //    bucket          = "<mylogs>.s3.amazonaws.com"
  //    prefix          = "geofencing"
  //  }

  default_cache_behavior {
    allowed_methods = [
      "DELETE",
      "GET",
      "HEAD",
      "OPTIONS",
      "PATCH",
      "POST",
    "PUT"]
    cached_methods = [
      "GET",
    "HEAD"]
    target_origin_id = local.cf_origin_id

    forwarded_values {
      query_string = true

      cookies {
        forward = "all"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  aliases = ["login.${var.domain_name}"]

  price_class = "PriceClass_100"

  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations = [
      "CA"]
    }
  }

  tags = local.common_tags

  viewer_certificate {
    cloudfront_default_certificate = false
    acm_certificate_arn            = aws_acm_certificate_validation.this.certificate_arn
    minimum_protocol_version       = "TLSv1.2_2021"
    ssl_support_method             = "sni-only"
  }
}

output "cloudfront_url" {
  value = "https://${aws_cloudfront_distribution.geofencing.domain_name}/${aws_api_gateway_deployment.samlpost.stage_name}"
}

output "login_domain_name" {
  value = "https://login.${var.domain_name}/${aws_api_gateway_deployment.samlpost.stage_name}"
}