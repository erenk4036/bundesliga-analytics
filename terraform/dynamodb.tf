# DynamoDB Table - Odds Data
resource "aws_dynamodb_table" "odds" {
  name         = "${var.project_name}-odds-${var.environment}"
  billing_mode = "PAY_PER_REQUEST"  # On-demand pricing
  
  hash_key  = "game_id"
  range_key = "timestamp"
  
  attribute {
    name = "game_id"
    type = "S"
  }
  
  attribute {
    name = "timestamp"
    type = "S"
  }
  
  # Point-in-Time Recovery (Backup)
  point_in_time_recovery {
    enabled = true
  }
  
  # TTL for automatic deletion (after 90 days)
  ttl {
    attribute_name = "expiration_time"
    enabled        = true
  }
  
  tags = {
    Name = "${var.project_name}-odds-table-${var.environment}"
  }
}

# DynamoDB Table - Value Bets (for frontend queries)
resource "aws_dynamodb_table" "value_bets" {
  name         = "${var.project_name}-value-bets-${var.environment}"
  billing_mode = "PAY_PER_REQUEST"
  
  hash_key  = "date"
  range_key = "value_percentage"
  
  attribute {
    name = "date"
    type = "S"
  }
  
  attribute {
    name = "value_percentage"
    type = "N"
  }
  
  point_in_time_recovery {
    enabled = true
  }
  
  ttl {
    attribute_name = "expiration_time"
    enabled        = true
  }
  
  tags = {
    Name = "${var.project_name}-value-bets-table-${var.environment}"
  }
}