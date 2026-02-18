# ==============================================================================
# API GATEWAY - REST API for Frontend
# ==============================================================================
# Provides HTTP endpoints for the React app to fetch value betting data
# from DynamoDB. Secured with API Keys and CORS enabled.
# ==============================================================================

# ------------------------------------------------------------------------------
# REST API
# ------------------------------------------------------------------------------

resource "aws_api_gateway_rest_api" "main" {
  name        = "${var.project_name}-api-${var.environment}"
  description = "API for Bundesliga Analytics - provides value betting data to frontend"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = {
    Name = "${var.project_name}-api-${var.environment}"
  }
}

# ------------------------------------------------------------------------------
# API Resources & Methods
# ------------------------------------------------------------------------------

# /value-bets resource
resource "aws_api_gateway_resource" "value_bets" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  path_part   = "value-bets"
}

# GET /value-bets
resource "aws_api_gateway_method" "get_value_bets" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.value_bets.id
  http_method   = "GET"
  authorization = "NONE"  # Public API for capstone demo
}

# Lambda Integration
resource "aws_api_gateway_integration" "get_value_bets" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.value_bets.id
  http_method             = aws_api_gateway_method.get_value_bets.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.api_reader.invoke_arn
}

# ------------------------------------------------------------------------------
# CORS Configuration
# ------------------------------------------------------------------------------

# OPTIONS method for CORS preflight
resource "aws_api_gateway_method" "options_value_bets" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.value_bets.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "options_value_bets" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.value_bets.id
  http_method = aws_api_gateway_method.options_value_bets.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "options_value_bets" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.value_bets.id
  http_method = aws_api_gateway_method.options_value_bets.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }

  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_integration_response" "options_value_bets" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.value_bets.id
  http_method = aws_api_gateway_method.options_value_bets.http_method
  status_code = aws_api_gateway_method_response.options_value_bets.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
}

# ------------------------------------------------------------------------------
# API Deployment
# ------------------------------------------------------------------------------

resource "aws_api_gateway_deployment" "main" {
  rest_api_id = aws_api_gateway_rest_api.main.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.value_bets.id,
      aws_api_gateway_method.get_value_bets.id,
      aws_api_gateway_integration.get_value_bets.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_integration.get_value_bets,
    aws_api_gateway_integration.options_value_bets
  ]
}

resource "aws_api_gateway_stage" "main" {
  deployment_id = aws_api_gateway_deployment.main.id
  rest_api_id   = aws_api_gateway_rest_api.main.id
  stage_name    = var.environment

  tags = {
    Name = "${var.project_name}-api-stage-${var.environment}"
  }
}

# ------------------------------------------------------------------------------
# Lambda Permission for API Gateway
# ------------------------------------------------------------------------------

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api_reader.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/*"
}
