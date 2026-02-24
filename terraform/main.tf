terraform {
  required_version = ">= 1.0.0"

  # Remote Backend for persistent state management
  backend "s3" {
    bucket  = "eren-kolac-terraform-state-bucket"
    key     = "bundesliga-analytics/terraform.tfstate"
    region  = "eu-central-1" 
    encrypt = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.32.0" 
    }

    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }

    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = var.common_tags
  }
}

# Random ID for unique bucket names
resource "random_id" "suffix" {
  byte_length = 4
}