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

# ---- Comprehensive Deployment Summary ----

output "summary" {
  description = "Deployment Summary"
  value       = <<-EOT
    ╔═══════════════════════════════════════════════════════════════════════════╗
    ║                   BUNDESLIGA ANALYTICS - DEPLOYMENT SUMMARY               ║
    ╚═══════════════════════════════════════════════════════════════════════════╝
    
    PROJECT INFORMATION
    ├─ Environment:     ${var.environment}
    ├─ Region:          ${var.aws_region}
    └─ Project:         ${var.project_name}
    
    NETWORKING
    ├─ VPC ID:          ${aws_vpc.main.id}
    ├─ CIDR Block:      ${aws_vpc.main.cidr_block}
    ├─ Public Subnets:  ${length(aws_subnet.public)} (${join(", ", [for s in aws_subnet.public : s.availability_zone])})
    └─ Private Subnets: ${length(aws_subnet.private)} (${join(", ", [for s in aws_subnet.private : s.availability_zone])})
    
    STORAGE
    ├─ Raw Data Bucket:       ${aws_s3_bucket.raw.bucket}
    │  └─ Lifecycle:          90 days retention
    └─ Processed Data Bucket: ${aws_s3_bucket.processed.bucket}
       └─ Lifecycle:          30d → Intelligent Tiering → 90d Glacier → 365d Delete
    
    DATABASE (DynamoDB)
    ├─ Odds Table:       ${aws_dynamodb_table.odds.name}
    │  ├─ Billing Mode:  PAY_PER_REQUEST
    │  ├─ Keys:          game_id (HASH), timestamp (RANGE)
    │  └─ TTL:           90 days
    └─ Value Bets Table: ${aws_dynamodb_table.value_bets.name}
       ├─ Billing Mode:  PAY_PER_REQUEST
       ├─ Keys:          date (HASH), value_percentage (RANGE)
       └─ TTL:           90 days
    
    ETL PIPELINE (Lambda Functions)
    ├─ Stage 1 - Extract:   ${aws_lambda_function.fetch_odds.function_name}
    │  ├─ Runtime:          python3.12 | 256 MB | 60s timeout
    │  ├─ Schedule:         ${aws_cloudwatch_event_rule.fetch_odds_schedule.schedule_expression}
    │  └─ Log Group:        ${aws_cloudwatch_log_group.fetch_odds.name}
    │
    ├─ Stage 2 - Transform: ${aws_lambda_function.transform_data.function_name}
    │  ├─ Runtime:          python3.12 | 512 MB | 120s timeout
    │  ├─ Schedule:         ${aws_cloudwatch_event_rule.transform_data_schedule.schedule_expression}
    │  └─ Log Group:        ${aws_cloudwatch_log_group.transform_data.name}
    │
    └─ Stage 3 - Load:      ${aws_lambda_function.analytics.function_name}
       ├─ Runtime:          python3.12 | 256 MB | 120s timeout
       ├─ Schedule:         ${aws_cloudwatch_event_rule.analytics_schedule.schedule_expression}
       └─ Log Group:        ${aws_cloudwatch_log_group.analytics.name}
    
    SHARED DEPENDENCIES
    ├─ Lambda Layer:     ${aws_lambda_layer_version.common_dependencies.layer_name}
    ├─ Version:          ${aws_lambda_layer_version.common_dependencies.version}
    └─ Dependencies:     requests, boto3, python-dotenv
    
    SECURITY
    ├─ IAM Role:         ${aws_iam_role.lambda_execution.name}
    ├─ Secrets Manager:  ${aws_secretsmanager_secret.odds_api_key.name}
    └─ Encryption:       AES256 (S3), At-Rest (DynamoDB)
    
    MONITORING
    ├─ CloudWatch Logs:  14-day retention
    ├─ X-Ray Tracing:    ${var.enable_xray_tracing ? "Enabled" : "Disabled"}
    └─ Metrics:          Custom namespace: ${var.project_name}/${var.environment}
    
    DEPLOYMENT STATUS: SUCCESS
    
    ╚═══════════════════════════════════════════════════════════════════════════╝
  EOT
}
