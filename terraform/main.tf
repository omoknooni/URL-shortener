# S3 bucket
# Need to upload frontend page code after the apply terraform
resource "aws_s3_bucket" "static_site" {
  bucket = "${var.subdomain_name}.${var.domain_name}"

  tags = {
    Name = "URL Shortener Static Site"
  }
}

resource "aws_s3_bucket_website_configuration" "url-shortener-front" {
  bucket = aws_s3_bucket.static_site
  index_document {
    suffix = "index.html"
  }
}

resource "aws_s3_bucket_policy" "static_site_policy" {
  bucket = aws_s3_bucket.static_site.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow"
      Principal = "*"
      Action    = "s3:GetObject"
      Resource  = "${aws_s3_bucket.static_site.arn}/*"
    }]
  })
}

resource "aws_s3_object" "index_obj" {
    bucket = aws_s3_bucket.static_site.id
    key    = "index.html"
    source = "url-shortener/index.html"
    content_type = "text/html"
}

# IAM Policy for Lambda
resource "aws_iam_policy" "url-shortener-dynamodb" {
  name = "shortener"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = [
          "dynamodb:GetItem",
          "dynamodb:PutItem"
        ],
        Resource = [
          "${aws_dynamodb_table.url-shortener.arn}"
        ]
      }
    ]
  })
}

# IAM role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = var.lambda_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Sid       = ""
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
resource "aws_iam_role_policy_attachment" "shortener" {
  role = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.url-shortener-dynamodb.arn
}

# Lambda functions
resource "aws_lambda_function" "shortener" {
  filename = "lambda/url-shorten.zip"
  function_name = "url-shortener-shortener"
  role = aws_iam_role.lambda_role.arn
  handler = "url-shortener.lambda_handler"
  runtime = "python3.12"
  source_code_hash = filebase64sha256("lambda/url-shorten.zip")

  environment {
    variables = {
      "DYNAMODB_TABLE" = aws_dynamodb_table.url-shortener.name
    }
  }
}

resource "aws_lambda_function" "redirecter" {
  filename = "lambda/url-redirect.zip"
  function_name = "url-shortener-redirecter"
  role = aws_iam_role.lambda_role.arn
  handler = "url-redirect.lambda_handler"
  runtime = "python3.12"
  source_code_hash = filebase64sha256("lambda/url-redirect.zip")
  environment {
    variables = {
      "DYNAMODB_TABLE" = aws_dynamodb_table.url-shortener.name
    }
  }
}

resource "aws_lambda_function" "mock" {
    filename = "lambda/mock.zip"
    function_name = "url-shortener-mock"
    role = aws_iam_role.lambda_role.arn
    handler = "mock.lambda_handler"
    runtime = "python3.12"
    source_code_hash = filebase64sha256("lambda/mock.zip")
}

# DynamoDB table
resource "aws_dynamodb_table" "url-shortener" {
    name = "url-shortener-table"
    billing_mode = "PAY_PER_REQUEST"
    hash_key = "short_id"

    attribute {
        name = "short_id"
        type = "S"
    }
}

# API Gateway
resource "aws_apigatewayv2_api" "http_api" {
  name          = var.api_gateway_name
  protocol_type = "HTTP"

  cors_configuration {
    allow_headers = [
        "Content-Type",
        "X-Amz-Date",
        "Authorization",
        "X-Api-Key",
        "X-Amz-Security-Token",
    ]
    allow_methods = [
        "GET",
        "OPTIONS",
        "POST",
    ]
    allow_origins = [
      "*"
    ]
  }
}

resource "aws_apigatewayv2_integration" "shorten_integration" {
  api_id           = aws_apigatewayv2_api.http_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.shorten.arn
  integration_method = "POST"
}

resource "aws_apigatewayv2_integration" "redirect_integration" {
  api_id           = aws_apigatewayv2_api.http_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.redirect.arn
  integration_method = "GET"
}

resource "aws_apigatewayv2_integration" "shorten_preflight_integration" {
  api_id = aws_apigatewayv2_api.http_api.id
  integration_type = "AWS_PROXY"
  integration_uri = aws_lambda_function.mock.arn
  integration_method = "OPTIONS"
}

resource "aws_apigatewayv2_route" "shorten_route" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "POST /api/conv"
  target    = "integrations/${aws_apigatewayv2_integration.shorten_integration.id}"
}

resource "aws_apigatewayv2_route" "redirect_route" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "GET /a/{short_id}"
  target    = "integrations/${aws_apigatewayv2_integration.redirect_integration.id}"
}

resource "aws_apigatewayv2_stage" "default_stage" {
  api_id      = aws_apigatewayv2_api.http_api.id
  name        = "$default"
  auto_deploy = true
}

# ACM in us-east-1 for CloudFront
data "aws_acm_certificate" "issued" {
  domain   = var.domain_name
  statuses = ["ISSUED"]
}

# CloudFront Distribution
resource "aws_cloudfront_distribution" "distribution" {
  origin {
    domain_name = aws_s3_bucket.static_site.bucket_regional_domain_name
    origin_id   = "S3-page"
  }

  origin {
    domain_name = aws_apigatewayv2_api.http_api.api_endpoint
    origin_id   = "APIGW"

    custom_origin_config {
        http_port = 80
        https_port = 443
        origin_protocol_policy = "https-only"
        origin_ssl_protocols = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    target_origin_id = aws_s3_bucket.static_site.id
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods = ["GET", "HEAD"]
    cache_policy_id = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"    # CachingDisabled, https://docs.aws.amazon.com/ko_kr/AmazonCloudFront/latest/DeveloperGuide/using-managed-cache-policies.html
  }

  ordered_cache_behavior {
    path_pattern = "/api/*"
    target_origin_id = aws_apigatewayv2_api.http_api.id
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods = ["GET", "HEAD"]
    cache_policy_id = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"
    origin_request_policy_id = "b689b0a8-53d0-40ab-baf2-68738e2966ac"   # AllViewerExceptHostHeader, https://docs.aws.amazon.com/ko_kr/AmazonCloudFront/latest/DeveloperGuide/using-managed-origin-request-policies.html
  }

  ordered_cache_behavior {
    path_pattern = "/a/*"
    target_origin_id = aws_apigatewayv2_api.http_api.id
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods = ["GET", "HEAD"]
    cache_policy_id = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"
    origin_request_policy_id = "b689b0a8-53d0-40ab-baf2-68738e2966ac"

  }

  enabled             = true
  is_ipv6_enabled     = false
  comment             = "URL Shortener CloudFront Distribution"
  default_root_object = "index.html"
  aliases = [ "url.omoknooni.link" ]

  # distribution의 geo_restriction
  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = ["KR"]
    }
  }

  # distribution의 SSL 설정
  viewer_certificate {
    cloudfront_default_certificate = false
    acm_certificate_arn = data.aws_acm_certificate.issued.arn
    minimum_protocol_version = "TLSv1.2_2021"
    ssl_support_method = "sni-only"
  }
}

# Route53 hosted zone and record
data "aws_route53_zone" "domain" {
  name = var.domain_name
}

resource "aws_route53_record" "service-record" {
  zone_id = data.aws_route53_zone.domain.zone_id
  name = "${var.subdomain_name}.${var.domain_name}"
  type = "A"

  alias {
    name = aws_cloudfront_distribution.distribution.domain_name
    zone_id = aws_cloudfront_distribution.distribution.hosted_zone_id
    evaluate_target_health = false
  }
}