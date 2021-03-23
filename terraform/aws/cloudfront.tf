locals {
	cf_origin_id = "api_gateway_saml"
}

resource "aws_cloudfront_distribution" "geofencing" {
	provider = aws.iam-security-account

	depends_on = [
		aws_api_gateway_deployment.samlpost]
	origin {
		custom_origin_config {
			http_port = 80
			https_port = 443
			origin_protocol_policy = "https-only"
			origin_ssl_protocols = [
				"TLSv1.2"]
		}

		domain_name = trimsuffix(trimprefix(aws_api_gateway_deployment.samlpost.invoke_url, "https://"), "/${aws_api_gateway_deployment.samlpost.stage_name}")
		origin_id = local.cf_origin_id

	}

	enabled = true
	is_ipv6_enabled = true
	comment = "geofencing"

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
		min_ttl = 0
		default_ttl = 3600
		max_ttl = 86400
	}

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
		cloudfront_default_certificate = true
	}
}

output "cloudfront_url" {
	value = "https://${aws_cloudfront_distribution.geofencing.domain_name}/${aws_api_gateway_deployment.samlpost.stage_name}"
}
