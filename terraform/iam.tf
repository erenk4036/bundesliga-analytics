resource "aws_iam_role" "lambda_execution" {
  name               = "${var.project_name}-lambda-execution-role-${var.environment}"
  description        = "Execution role for Lambda functions with least privilege access"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json

  tags = {
    Name = "${var.project_name}-lambda-role-${var.environment}"
  }
}

# Assume Role Policy - Allow Lambda service to assume this role
data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

# Attach AWS Managed Policy - Basic Lambda Execution
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Attach AWS Managed Policy - VPC Execution
resource "aws_iam_role_policy_attachment" "lambda_vpc_execution" {
  count      = var.enable_nat_gateway ? 1 : 0
  role       = aws_iam_role.lambda_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Custom IAM Policy - S3 Access
resource "aws_iam_role_policy" "lambda_s3_access" {
  name   = "${var.project_name}-lambda-s3-policy-${var.environment}"
  role   = aws_iam_role.lambda_execution.id
  policy = data.aws_iam_policy_document.lambda_s3_access.json
}

data "aws_iam_policy_document" "lambda_s3_access" {
  statement {
    sid    = "S3ReadWriteAccess"
    effect = "Allow"

    actions = [
      "s3:PutObject",
      "s3:PutObjectAcl",
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:ListBucket"
    ]

    resources = [
      aws_s3_bucket.raw.arn,
      "${aws_s3_bucket.raw.arn}/*",
      aws_s3_bucket.processed.arn,
      "${aws_s3_bucket.processed.arn}/*"
    ]
  }

  statement {
    sid    = "S3ListBucketsAccess"
    effect = "Allow"

    actions = [
      "s3:ListAllMyBuckets",
      "s3:GetBucketLocation"
    ]

    resources = ["*"]
  }
}

# Custom IAM Policy - DynamoDB Access
resource "aws_iam_role_policy" "lambda_dynamodb_access" {
  name   = "${var.project_name}-lambda-dynamodb-policy-${var.environment}"
  role   = aws_iam_role.lambda_execution.id
  policy = data.aws_iam_policy_document.lambda_dynamodb_access.json
}

data "aws_iam_policy_document" "lambda_dynamodb_access" {
  statement {
    sid    = "DynamoDBWriteAccess"
    effect = "Allow"

    actions = [
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
      "dynamodb:DeleteItem",
      "dynamodb:BatchWriteItem"
    ]

    resources = [
      aws_dynamodb_table.odds.arn,
      aws_dynamodb_table.value_bets.arn
    ]
  }

  statement {
    sid    = "DynamoDBReadAccess"
    effect = "Allow"

    actions = [
      "dynamodb:GetItem",
      "dynamodb:Query",
      "dynamodb:Scan",
      "dynamodb:BatchGetItem",
      "dynamodb:DescribeTable"
    ]

    resources = [
      aws_dynamodb_table.odds.arn,
      aws_dynamodb_table.value_bets.arn,
      "${aws_dynamodb_table.odds.arn}/index/*",
      "${aws_dynamodb_table.value_bets.arn}/index/*"
    ]
  }
}

# Custom IAM Policy - Secrets Manager Access
resource "aws_iam_role_policy" "lambda_secrets_access" {
  name   = "${var.project_name}-lambda-secrets-policy-${var.environment}"
  role   = aws_iam_role.lambda_execution.id
  policy = data.aws_iam_policy_document.lambda_secrets_access.json
}

data "aws_iam_policy_document" "lambda_secrets_access" {
  statement {
    sid    = "SecretsManagerReadAccess"
    effect = "Allow"

    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret"
    ]

    resources = [
      aws_secretsmanager_secret.odds_api_key.arn
    ]
  }
}

# Custom IAM Policy - CloudWatch Logs (Enhanced)
resource "aws_iam_role_policy" "lambda_cloudwatch_enhanced" {
  name   = "${var.project_name}-lambda-cloudwatch-policy-${var.environment}"
  role   = aws_iam_role.lambda_execution.id
  policy = data.aws_iam_policy_document.lambda_cloudwatch_enhanced.json
}

data "aws_iam_policy_document" "lambda_cloudwatch_enhanced" {
  statement {
    sid    = "CloudWatchLogsAccess"
    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams"
    ]

    resources = [
      "arn:aws:logs:${var.aws_region}:*:log-group:/aws/lambda/${var.project_name}-*"
    ]
  }

  statement {
    sid    = "CloudWatchMetricsAccess"
    effect = "Allow"

    actions = [
      "cloudwatch:PutMetricData"
    ]

    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "cloudwatch:namespace"
      values   = ["${var.project_name}/${var.environment}"]
    }
  }
}

# Optional: Custom IAM Policy - X-Ray Tracing
resource "aws_iam_role_policy" "lambda_xray_access" {
  count  = var.enable_xray_tracing ? 1 : 0
  name   = "${var.project_name}-lambda-xray-policy-${var.environment}"
  role   = aws_iam_role.lambda_execution.id
  policy = data.aws_iam_policy_document.lambda_xray_access.json
}

data "aws_iam_policy_document" "lambda_xray_access" {
  statement {
    sid    = "XRayAccess"
    effect = "Allow"

    actions = [
      "xray:PutTraceSegments",
      "xray:PutTelemetryRecords"
    ]

    resources = ["*"]
  }
}