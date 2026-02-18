output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "Public Subnet IDs"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Private Subnet IDs"
  value       = aws_subnet.private[*].id
}

output "raw_bucket_name" {
  description = "S3 Raw Data Bucket Name"
  value       = aws_s3_bucket.raw.bucket
}

output "processed_bucket_name" {
  description = "S3 Processed Data Bucket Name"
  value       = aws_s3_bucket.processed.bucket
}

output "dynamodb_odds_table" {
  description = "DynamoDB Odds Table Name"
  value       = aws_dynamodb_table.odds.name
}

output "dynamodb_value_bets_table" {
  description = "DynamoDB Value Bets Table Name"
  value       = aws_dynamodb_table.value_bets.name
}

output "lambda_execution_role_arn" {
  description = "ARN of Lambda execution role"
  value       = aws_iam_role.lambda_execution.arn
}

output "lambda_execution_role_name" {
  description = "Name of Lambda execution role"
  value       = aws_iam_role.lambda_execution.name
}

output "secrets_manager_arn" {
  description = "ARN of Secrets Manager secret"
  value       = aws_secretsmanager_secret.odds_api_key.arn
  sensitive   = true
}

output "secrets_manager_name" {
  description = "Name of Secrets Manager secret"
  value       = aws_secretsmanager_secret.odds_api_key.name
}

# ---- Lambda Function ARNs ----

output "lambda_fetch_odds_arn" {
  description = "ARN of the fetch_odds Lambda function"
  value       = aws_lambda_function.fetch_odds.arn
}

output "lambda_transform_data_arn" {
  description = "ARN of the transform_data Lambda function"
  value       = aws_lambda_function.transform_data.arn
}

output "lambda_analytics_arn" {
  description = "ARN of the analytics Lambda function"
  value       = aws_lambda_function.analytics.arn
}

# ---- Lambda Layer ----

output "lambda_layer_arn" {
  description = "ARN of the shared Lambda dependency layer (with version)"
  value       = aws_lambda_layer_version.common_dependencies.arn
}

output "lambda_layer_version" {
  description = "Published version number of the common dependency layer"
  value       = aws_lambda_layer_version.common_dependencies.version
}

# ---- CloudWatch Log Groups ----

output "log_group_fetch_odds" {
  description = "CloudWatch Log Group for fetch_odds Lambda"
  value       = aws_cloudwatch_log_group.fetch_odds.name
}

output "log_group_transform_data" {
  description = "CloudWatch Log Group for transform_data Lambda"
  value       = aws_cloudwatch_log_group.transform_data.name
}

output "log_group_analytics" {
  description = "CloudWatch Log Group for analytics Lambda"
  value       = aws_cloudwatch_log_group.analytics.name
}

# ---- EventBridge Schedules ----

output "schedule_fetch_odds" {
  description = "EventBridge schedule expression for fetch_odds"
  value       = aws_cloudwatch_event_rule.fetch_odds_schedule.schedule_expression
}

output "schedule_transform_data" {
  description = "EventBridge schedule expression for transform_data"
  value       = aws_cloudwatch_event_rule.transform_data_schedule.schedule_expression
}

output "schedule_analytics" {
  description = "EventBridge schedule expression for analytics"
  value       = aws_cloudwatch_event_rule.analytics_schedule.schedule_expression
}

# ---- Website & API Outputs ----

output "website_bucket_name" {
  description = "S3 bucket name for static website"
  value       = aws_s3_bucket.website.bucket
}

output "website_endpoint" {
  description = "S3 website endpoint URL"
  value       = aws_s3_bucket_website_configuration.website.website_endpoint
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID"
  value       = aws_cloudfront_distribution.website.id
}

output "cloudfront_domain_name" {
  description = "CloudFront domain name (access to website)"
  value       = aws_cloudfront_distribution.website.domain_name
}

output "website_url" {
  description = "Complete HTTPS URL"
  value       = "https://${aws_cloudfront_distribution.website.domain_name}"
}

output "api_gateway_url" {
  description = "API Gateway endpoint URL for value bets"
  value       = "${aws_api_gateway_stage.main.invoke_url}/value-bets"
}

output "api_gateway_base_url" {
  description = "API Gateway base URL"
  value       = aws_api_gateway_stage.main.invoke_url
}

output "api_reader_lambda_arn" {
  description = "ARN of the API reader Lambda function"
  value       = aws_lambda_function.api_reader.arn
}

# ---- Deployment Summary ----

output "deployment_summary" {
  description = "Quick reference deployment info"
  value = {
    website_url    = "https://${aws_cloudfront_distribution.website.domain_name}"
    api_url        = "${aws_api_gateway_stage.main.invoke_url}/value-bets"
    website_bucket = aws_s3_bucket.website.bucket
    cloudfront_id  = aws_cloudfront_distribution.website.id
  }
}
