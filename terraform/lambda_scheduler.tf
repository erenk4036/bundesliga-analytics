# ==============================================================================
# EVENTBRIDGE SCHEDULER - Automated ETL Pipeline Orchestration
# ==============================================================================
# Pipeline execution order (sequential via staggered cron times):
#
#   Step 1 - fetch_odds     → runs at  06:00 UTC (fetches fresh odds)
#   Step 2 - transform_data → runs at  06:10 UTC (10min buffer for fetch to finish)
#   Step 3 - analytics      → runs at  06:20 UTC (10min buffer for transform)
#
# ==============================================================================

# ------------------------------------------------------------------------------
# STAGE 1: Schedule - fetch_odds (daily 06:00 UTC)
# ------------------------------------------------------------------------------

resource "aws_cloudwatch_event_rule" "fetch_odds_schedule" {
  name                = "${var.project_name}-fetch-odds-schedule-${var.environment}"
  description         = "Triggers fetch_odds Lambda daily at 06:00 UTC"
  schedule_expression = "cron(0 6 * * ? *)"   # Every day at 06:00 UTC
  state               = "ENABLED"

  tags = {
    Name     = "${var.project_name}-fetch-odds-schedule-${var.environment}"
    Pipeline = "etl-stage-1"
  }
}

resource "aws_cloudwatch_event_target" "fetch_odds_target" {
  rule      = aws_cloudwatch_event_rule.fetch_odds_schedule.name
  target_id = "FetchOddsLambdaTarget"
  arn       = aws_lambda_function.fetch_odds.arn
}

resource "aws_lambda_permission" "allow_eventbridge_fetch_odds" {
  statement_id  = "AllowEventBridgeInvokeFetchOdds"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.fetch_odds.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.fetch_odds_schedule.arn
}

# ------------------------------------------------------------------------------
# STAGE 2: Schedule - transform_data (daily 06:10 UTC)
# ------------------------------------------------------------------------------

resource "aws_cloudwatch_event_rule" "transform_data_schedule" {
  name                = "${var.project_name}-transform-data-schedule-${var.environment}"
  description         = "Triggers transform_data Lambda daily at 06:10 UTC"
  schedule_expression = "cron(10 6 * * ? *)"  # Every day at 06:10 UTC
  state               = "ENABLED"

  tags = {
    Name     = "${var.project_name}-transform-data-schedule-${var.environment}"
    Pipeline = "etl-stage-2"
  }
}

resource "aws_cloudwatch_event_target" "transform_data_target" {
  rule      = aws_cloudwatch_event_rule.transform_data_schedule.name
  target_id = "TransformDataLambdaTarget"
  arn       = aws_lambda_function.transform_data.arn
}

resource "aws_lambda_permission" "allow_eventbridge_transform_data" {
  statement_id  = "AllowEventBridgeInvokeTransformData"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.transform_data.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.transform_data_schedule.arn
}

# ------------------------------------------------------------------------------
# STAGE 3: Schedule - analytics (daily 06:20 UTC)
# ------------------------------------------------------------------------------

resource "aws_cloudwatch_event_rule" "analytics_schedule" {
  name                = "${var.project_name}-analytics-schedule-${var.environment}"
  description         = "Triggers analytics Lambda daily at 06:20 UTC"
  schedule_expression = "cron(20 6 * * ? *)"  # Every day at 06:20 UTC
  state               = "ENABLED"

  tags = {
    Name     = "${var.project_name}-analytics-schedule-${var.environment}"
    Pipeline = "etl-stage-3"
  }
}

resource "aws_cloudwatch_event_target" "analytics_target" {
  rule      = aws_cloudwatch_event_rule.analytics_schedule.name
  target_id = "AnalyticsLambdaTarget"
  arn       = aws_lambda_function.analytics.arn
}

resource "aws_lambda_permission" "allow_eventbridge_analytics" {
  statement_id  = "AllowEventBridgeInvokeAnalytics"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.analytics.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.analytics_schedule.arn
}
