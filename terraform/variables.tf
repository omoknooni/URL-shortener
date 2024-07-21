variable "region" {
  description = "AWS region"
  default     = "us-east-1"
}

variable "s3_bucket_name" {
  description = "S3 bucket name for static hosting"
  default     = "url.omoknooni.link"
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
