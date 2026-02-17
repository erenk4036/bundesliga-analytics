variable "project_name" {
  description = "Name of project"
  type        = string
  default     = "bundesliga-analytics"
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "dev"
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be 'dev', 'staging' or 'prod'."
  }
}

variable "aws_region" {
  description = "AWS Region"
  type        = string
  default     = "eu-central-1"
}

variable "vpc_cidr" {
  description = "CIDR Block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability Zones for Subnets"
  type        = list(string)
  default     = ["eu-central-1a", "eu-central-1b"]
}

variable "tags" {
  description = "Standard Tags for all resources"
  type        = map(string)
  default = {
    Project    = "Bundesliga Analytics"
    ManagedBy  = "Terraform"
    Repository = "github.com/erenk4036/bundesliga-analytics"
  }
}

variable "odds_api_key" {
  description = "API Key for The Odds API (stored in AWS Secrets Manager)"
  type        = string
  sensitive   = true
}

variable "enable_xray_tracing" {
  description = "Enable X-Ray Tracing for Lambda Functions"
  type        = bool
  default     = false
}