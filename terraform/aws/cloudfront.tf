locals {
  cf_origin_id = "api_gateway_saml"
}

resource "aws_cloudfront_distribution" "geofencing" {
  depends_on = [aws_api_gateway_deployment.samlpost]
  origin {
    #regex("^(?:(?P<scheme>[^:/?#]+):)?(?://(?P<authority>[^/?#]*))?", "${aws_api_gateway_deployment.samlpost.stage_name}")
    domain_name = trimsuffix(trimprefix(aws_api_gateway_deployment.samlpost.stage_name, "https://"), "/${aws_api_gateway_deployment.samlpost.stage_name}")
    origin_id   = local.cf_origin_id

  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "geofencing"
  default_root_object = ""

  logging_config {
    include_cookies = false
    bucket          = "<mylogs>.s3.amazonaws.com"
    prefix          = "geofencing"
  }

  aliases = [""]

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = []
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

  price_class = "PriceClass_100"

  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = ["CA"]
    }
  }

  tags = {
    Environment = locals.Environment
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}
