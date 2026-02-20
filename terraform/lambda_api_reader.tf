# ==============================================================================
# LAMBDA FUNCTION - API Reader
# ==============================================================================
# Reads value betting data from DynamoDB and serves it via API Gateway
# to the frontend React application.
# ==============================================================================

# ------------------------------------------------------------------------------
# Archive the Lambda Function
# ------------------------------------------------------------------------------

data "archive_file" "api_reader" {
  type        = "zip"
  source_file = "${path.module}/../src/lambda/api_reader.py"
  output_path = "${path.module}/.lambda_builds/api_reader.zip"
}

# ------------------------------------------------------------------------------
# CloudWatch Log Group
# ------------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "api_reader" {
  name              = "/aws/lambda/${var.project_name}-api-reader-${var.environment}"
  retention_in_days = 14

  tags = {
    Name     = "${var.project_name}-api-reader-logs-${var.environment}"
    Function = "api-reader"
  }
}

# ------------------------------------------------------------------------------
# Lambda Function
# ------------------------------------------------------------------------------

resource "aws_lambda_function" "api_reader" {
  function_name = "${var.project_name}-api-reader-${var.environment}"
  description   = "Reads value betting data from DynamoDB and serves via API Gateway"

  filename         = data.archive_file.api_reader.output_path
  source_code_hash = data.archive_file.api_reader.output_base64sha256

  handler = "api_reader.lambda_handler"
  runtime = "python3.12"
  role    = aws_iam_role.lambda_execution.arn

  timeout     = 30
  memory_size = 256

  dynamic "vpc_config" {
    for_each = var.lambda_in_vpc ? [1] : []

    content {
      subnet_ids         = aws_subnet.private[*].id
      security_group_ids = [aws_security_group.lambda[0].id]
    }
  }

  environment {
    variables = {
      ENVIRONMENT         = var.environment
      DYNAMODB_BETS_TABLE = aws_dynamodb_table.value_bets.name
      DYNAMODB_ODDS_TABLE = aws_dynamodb_table.odds.name
      LOG_LEVEL           = var.environment == "prod" ? "WARNING" : "INFO"
    }
  }

  tracing_config {
    mode = var.enable_xray_tracing ? "Active" : "PassThrough"
  }

  depends_on = [
    aws_cloudwatch_log_group.api_reader,
    aws_iam_role_policy_attachment.lambda_basic_execution
  ]

  tags = {
    Name       = "${var.project_name}-api-reader-${var.environment}"
    Function   = "api-backend"
    Purpose    = "serve-frontend-data"
    VPCEnabled = var.lambda_in_vpc ? "true" : "false"
  }
}
