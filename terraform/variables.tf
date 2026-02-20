# ==============================================================================
# VARIABLES - Infrastructure Configuration
# ==============================================================================

# ------------------------------------------------------------------------------
# Project Configuration
# ------------------------------------------------------------------------------

variable "project_name" {
  description = "Name of project"
  type        = string
  default     = "bundesliga-analytics"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be 'dev', 'staging' or 'prod'."
  }
}

# ------------------------------------------------------------------------------
# AWS Configuration
# ------------------------------------------------------------------------------

variable "aws_region" {
  description = "AWS region for resource deployment"
  type        = string
  default     = "eu-central-1"
}

variable "availability_zones" {
  description = "Availability Zones for Subnets"
  type        = list(string)
  default     = ["eu-central-1a", "eu-central-1b"]
}

# ------------------------------------------------------------------------------
# Networking Configuration
# ------------------------------------------------------------------------------

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway for private subnet internet access (required for Lambda in VPC)"
  type        = bool
  default     = false
}

variable "enable_vpc_endpoints" {
  description = "Enable VPC endpoints for DynamoDB and S3"
  type        = bool
  default     = false
}

# ------------------------------------------------------------------------------
# Lambda Configuration
# ------------------------------------------------------------------------------

variable "lambda_in_vpc" {
  description = "Deploy Lambda functions inside VPC with private subnets (production security best practice)"
  type        = bool
  default     = false
}

# ------------------------------------------------------------------------------
# API Configuration
# ------------------------------------------------------------------------------

variable "odds_api_key" {
  description = "API key for The Odds API (stored in Secrets Manager)"
  type        = string
  sensitive   = true
}

# ------------------------------------------------------------------------------
# Monitoring Configuration
# ------------------------------------------------------------------------------

variable "enable_xray_tracing" {
  description = "Enable X-Ray Tracing for Lambda Functions"
  type        = bool
  default     = false
}

# ------------------------------------------------------------------------------
# Tags
# ------------------------------------------------------------------------------

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    Project    = "Bundesliga Analytics"
    ManagedBy  = "Terraform"
    Repository = "github.com/erenk4036/bundesliga-analytics"
  }
}
