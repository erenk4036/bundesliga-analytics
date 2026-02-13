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

output "summary" {
  description = "Deployment Summary"
  value = <<-EOT
    ✅ Infrastructure deployed successfully!
    
    VPC:
    - VPC ID: ${aws_vpc.main.id}
    - CIDR: ${aws_vpc.main.cidr_block}
    - Public Subnets: ${length(aws_subnet.public)}
    - Private Subnets: ${length(aws_subnet.private)}
    
    Storage:
    - Raw Bucket: ${aws_s3_bucket.raw.bucket}
    - Processed Bucket: ${aws_s3_bucket.processed.bucket}
    
    Database:
    - Odds Table: ${aws_dynamodb_table.odds.name}
    - Value Bets Table: ${aws_dynamodb_table.value_bets.name}
  EOT
}