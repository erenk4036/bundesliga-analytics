# S3 Bucket - Raw Data
resource "aws_s3_bucket" "raw" {
  bucket = "${var.project_name}-raw-data-${random_id.suffix.hex}"
  
  tags = {
    Name        = "${var.project_name}-raw-data-${var.environment}"
    DataType    = "raw"
    Sensitivity = "low"
  }
}

# Raw Bucket - Versioning
resource "aws_s3_bucket_versioning" "raw" {
  bucket = aws_s3_bucket.raw.id
  
  versioning_configuration {
    status = "Enabled"
  }
}

# Raw Bucket - Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "raw" {
  bucket = aws_s3_bucket.raw.id
  
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Raw Bucket - Block Public Access
resource "aws_s3_bucket_public_access_block" "raw" {
  bucket = aws_s3_bucket.raw.id
  
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Raw Bucket - Lifecycle (Delete data after 90 days)
resource "aws_s3_bucket_lifecycle_configuration" "raw" {
  bucket = aws_s3_bucket.raw.id
  
  rule {
    id     = "delete-old-data"
    status = "Enabled"
    
    expiration {
      days = 90
    }
  }
}

# S3 Bucket - Processed Data
resource "aws_s3_bucket" "processed" {
  bucket = "${var.project_name}-processed-data-${random_id.suffix.hex}"
  
  tags = {
    Name        = "${var.project_name}-processed-data-${var.environment}"
    DataType    = "processed"
    Sensitivity = "medium"
  }
}

# Processed Bucket - Versioning
resource "aws_s3_bucket_versioning" "processed" {
  bucket = aws_s3_bucket.processed.id
  
  versioning_configuration {
    status = "Enabled"
  }
}

# Processed Bucket - Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "processed" {
  bucket = aws_s3_bucket.processed.id
  
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Processed Bucket - Block Public Access
resource "aws_s3_bucket_public_access_block" "processed" {
  bucket = aws_s3_bucket.processed.id
  
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Processed Bucket - Lifecycle 
resource "aws_s3_bucket_lifecycle_configuration" "processed" {
  bucket = aws_s3_bucket.processed.id
  
  rule {
    id     = "transition-to-glacier"
    status = "Enabled"
    
    transition {
      days          = 30
      storage_class = "INTELLIGENT_TIERING"
    }
    
    transition {
      days          = 90
      storage_class = "GLACIER"
    }
    
    expiration {
      days = 365
    }
  }
}