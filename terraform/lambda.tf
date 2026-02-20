# ------------------------------------------------------------------------------ 
# LAMDA FUNCTIONS - ETL Pipeline
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Security Group for Lambda Functions (only when running in VPC)
# ------------------------------------------------------------------------------

resource "aws_security_group" "lambda" {
  count       = var.lambda_in_vpc ? 1 : 0
  name        = "${var.project_name}-lambda-sg-${var.environment}"
  description = "Security group for Lambda functions in VPC"
  vpc_id      = aws_vpc.main.id

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "${var.project_name}-lambda-sg-${var.environment}"
  }
}



# ------------------------------------------------------------------------------
# Archive Lambda Function Code
# ------------------------------------------------------------------------------

data "archive_file" "fetch_odds" {
  type        = "zip"
  source_file = "${path.module}/../src/lambda/fetch_odds.py"
  output_path = "${path.module}/.lambda_builds/fetch_odds.zip"
}

data "archive_file" "transform_data" {
  type        = "zip"
  source_file = "${path.module}/../src/lambda/transform_data.py"
  output_path = "${path.module}/.lambda_builds/transform_data.zip"
}

data "archive_file" "analytics" {
  type        = "zip"
  source_file = "${path.module}/../src/lambda/analytics.py"
  output_path = "${path.module}/.lambda_builds/analytics.zip"
}

# ------------------------------------------------------------------------------
# CloudWatch Log Groups (created before Lambda to avoid race condition)
# with retention and managed by Terraform lifecycle
# ------------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "fetch_odds" {
  name              = "/aws/lambda/${var.project_name}-fetch-odds-${var.environment}"
  retention_in_days = 14

  tags = {
    Name      = "${var.project_name}-fetch-odds-logs-${var.environment}"
    Function  = "fetch-odds"
  }
}

resource "aws_cloudwatch_log_group" "transform_data" {
  name              = "/aws/lambda/${var.project_name}-transform-data-${var.environment}"
  retention_in_days = 14

  tags = {
    Name      = "${var.project_name}-transform-data-logs-${var.environment}"
    Function  = "transform-data"
  }
}

resource "aws_cloudwatch_log_group" "analytics" {
  name              = "/aws/lambda/${var.project_name}-analytics-${var.environment}"
  retention_in_days = 14

  tags = {
    Name      = "${var.project_name}-analytics-logs-${var.environment}"
    Function  = "analytics"
  }
}

# ------------------------------------------------------------------------------
# LAMBDA FUNCTION 1: fetch_odds
# Pulls live odds from The Odds API and writes raw JSON to S3
# ------------------------------------------------------------------------------

resource "aws_lambda_function" "fetch_odds" {
  function_name = "${var.project_name}-fetch-odds-${var.environment}"
  description   = "Fetches Bundesliga odds from The Odds API and stores raw data in S3"

  # Deployment package
  filename         = data.archive_file.fetch_odds.output_path
  source_code_hash = data.archive_file.fetch_odds.output_base64sha256

  # Handler format: <filename_without_extension>.<function_name>
  handler  = "fetch_odds.lambda_handler"
  runtime  = "python3.12"
  role     = aws_iam_role.lambda_execution.arn

  timeout      = 60   
  memory_size  = 256  

  # Conditional VPC Configuration
  # Only applies when lambda_in_vpc = true (production)
  # Requires NAT Gateway for internet access
  dynamic "vpc_config" {
    for_each = var.lambda_in_vpc ? [1] : []

    content {
      subnet_ids         = aws_subnet.private[*].id
      security_group_ids = [aws_security_group.lambda[0].id]
    }
  }

  # Lambda Layer - provides requests, python-dotenv etc.
  layers = [aws_lambda_layer_version.common_dependencies.arn]

  # Environment variables injected at runtime
  environment {
    variables = {
      ENVIRONMENT       = var.environment
      RAW_BUCKET_NAME   = aws_s3_bucket.raw.bucket
      SECRET_ARN        = aws_secretsmanager_secret.odds_api_key.arn
      SPORT             = "soccer_germany_bundesliga"
      REGION            = "eu"
      MARKETS           = "h2h"
      ODDS_FORMAT       = "decimal"
      LOG_LEVEL         = var.environment == "prod" ? "WARNING" : "INFO"
    }
  }

  # X-Ray Tracing (controlled via variable)
  tracing_config {
    mode = var.enable_xray_tracing ? "Active" : "PassThrough"
  }

  # Explicit dependency: Log group must exist before Lambda is created
  depends_on = [
    aws_cloudwatch_log_group.fetch_odds,
    aws_iam_role_policy_attachment.lambda_basic_execution
  ]

  tags = {
    Name     = "${var.project_name}-fetch-odds-${var.environment}"
    Function = "etl-stage-1"
    Stage    = "extract"
    VPCEnabled = var.lambda_in_vpc ? "true" : "false"
  }
}

# ------------------------------------------------------------------------------
# LAMBDA FUNCTION 2: transform_data
# Reads latest raw JSON from S3, computes value bets, writes to processed bucket
# ------------------------------------------------------------------------------

resource "aws_lambda_function" "transform_data" {
  function_name = "${var.project_name}-transform-data-${var.environment}"
  description   = "Transforms raw odds data into value betting analysis and stores in S3 processed bucket"

  filename         = data.archive_file.transform_data.output_path
  source_code_hash = data.archive_file.transform_data.output_base64sha256

  handler     = "transform_data.lambda_handler"
  runtime     = "python3.12"
  role        = aws_iam_role.lambda_execution.arn

  timeout     = 120   
  memory_size = 512  # testing with slightly higher Memory size and timeout

  dynamic "vpc_config" {
    for_each = var.lambda_in_vpc ? [1] : []

    content {
      subnet_ids         = aws_subnet.private[*].id
      security_group_ids = [aws_security_group.lambda[0].id]
    }
  }

  layers = [aws_lambda_layer_version.common_dependencies.arn]

  environment {
    variables = {
      ENVIRONMENT           = var.environment
      RAW_BUCKET_NAME       = aws_s3_bucket.raw.bucket
      PROCESSED_BUCKET_NAME = aws_s3_bucket.processed.bucket
      LOG_LEVEL             = var.environment == "prod" ? "WARNING" : "INFO"
    }
  }

  tracing_config {
    mode = var.enable_xray_tracing ? "Active" : "PassThrough"
  }

  depends_on = [
    aws_cloudwatch_log_group.transform_data,
    aws_iam_role_policy_attachment.lambda_basic_execution
  ]

  tags = {
    Name       = "${var.project_name}-transform-data-${var.environment}"
    Function   = "etl-stage-2"
    Stage      = "transform"
    VPCEnabled = var.lambda_in_vpc ? "true" : "false"
  }
}

# ------------------------------------------------------------------------------
# LAMBDA FUNCTION 3: analytics
# Reads processed value bets from S3 and writes high-conviction signals to DynamoDB
# ------------------------------------------------------------------------------

resource "aws_lambda_function" "analytics" {
  function_name = "${var.project_name}-analytics-${var.environment}"
  description   = "Analyzes value bets and writes results to DynamoDB"

  filename         = data.archive_file.analytics.output_path
  source_code_hash = data.archive_file.analytics.output_base64sha256

  handler     = "analytics.lambda_handler"
  runtime     = "python3.12"
  role        = aws_iam_role.lambda_execution.arn

  timeout     = 120
  memory_size = 256

  dynamic "vpc_config" {
    for_each = var.lambda_in_vpc ? [1] : []

    content {
      subnet_ids         = aws_subnet.private[*].id
      security_group_ids = [aws_security_group.lambda[0].id]
    }
  }

  layers = [aws_lambda_layer_version.common_dependencies.arn]

  environment {
    variables = {
      ENVIRONMENT           = var.environment
      PROCESSED_BUCKET_NAME = aws_s3_bucket.processed.bucket
      DYNAMODB_ODDS_TABLE   = aws_dynamodb_table.odds.name
      DYNAMODB_BETS_TABLE   = aws_dynamodb_table.value_bets.name
      LOG_LEVEL             = var.environment == "prod" ? "WARNING" : "INFO"
    }
  }

  tracing_config {
    mode = var.enable_xray_tracing ? "Active" : "PassThrough"
  }

  depends_on = [
    aws_cloudwatch_log_group.analytics,
    aws_iam_role_policy_attachment.lambda_basic_execution
  ]

  tags = {
    Name     = "${var.project_name}-analytics-${var.environment}"
    Function = "etl-stage-3"
    Stage    = "load"
    VPCEnabled = var.lambda_in_vpc ? "true" : "false"
  }
}
