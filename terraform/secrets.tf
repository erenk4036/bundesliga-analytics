resource "aws_secretsmanager_secret" "odds_api_key" {
  name        = "${var.project_name}-odds-api-key-${var.environment}"
  description = "The Odds API Key for Bundesliga data fetching"

  recovery_window_in_days = 7

  tags = {
    Name        = "${var.project_name}-api-secret-${var.environment}"
    Purpose     = "api-credentials"
    Sensitivity = "high"
  }
}

# Secret Version - Actual API Key Value
resource "aws_secretsmanager_secret_version" "odds_api_key" {
  secret_id = aws_secretsmanager_secret.odds_api_key.id

  secret_string = jsonencode({
    ODDS_API_KEY = var.odds_api_key
    API_ENDPOINT = "https://api.the-odds-api.com/v4"
    SPORT_KEY    = "soccer_germany_bundesliga"
    REGION       = "eu"
    MARKETS      = "h2h"
  })
}