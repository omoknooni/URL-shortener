output "s3_bucket_name" {
  value = aws_s3_bucket.static_site.bucket
}

output "api_gateway_url" {
  value = aws_apigatewayv2_api.http_api.api_endpoint
}

output "cloudfront_distribution_domain" {
  value = aws_cloudfront_distribution.distribution.domain_name
}
