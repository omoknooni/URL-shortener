variable "domain_name" {
  description = "domain name for service"
  default     = "omoknooni.link"
}

variable "subdomain_name" {
  description = "subdomain name for service"
  default = "s"
}

variable "lambda_role_name" {
  description = "IAM role for Lambda function"
  default     = "url-shortener-lambda-role"
}

variable "api_gateway_name" {
  description = "API Gateway name"
  default     = "url-shortener-api"
}

variable "cloudfront_origin_id_s3" {
  description = "CloudFront origin ID for S3"
  default     = "S3-StaticWebsite"
}

variable "cloudfront_origin_id_api" {
  description = "CloudFront origin ID for API Gateway"
  default     = "APIGateway"
}
