# ------------------------------------------------------------------------------
# LAMBDA LAYER - Common Python Dependencies
# ------------------------------------------------------------------------------
# Common Python dependencies shared across all Lambda functions
# Includes: requests, boto3, python-dotenv
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Build Lambda Layer (runs before layer creation)
# ------------------------------------------------------------------------------

# Null resource to build the layer if it doesn't exist
resource "null_resource" "build_lambda_layer" {
  # Trigger rebuild when requirements.txt changes
  triggers = {
    requirements = filemd5("${path.module}/layers/common/requirements.txt")
  }

  # Build the layer
  provisioner "local-exec" {
    command = <<-EOT
      set -e
      echo "Building Lambda Layer..."
      
      # Create build directory
      mkdir -p ${path.module}/.lambda_builds
      
      # Clean previous build
      rm -rf ${path.module}/layers/common/python
      
      # Install dependencies
      pip install \
        -r ${path.module}/layers/common/requirements.txt \
        -t ${path.module}/layers/common/python/ \
        --platform manylinux2014_x86_64 \
        --only-binary=:all: \
        --upgrade
      
      # Create ZIP
      cd ${path.module}
      cd layers/common
      zip -r ../../.lambda_builds/common_layer.zip python/
      cd ../..
      
      echo "Lambda Layer built successfully!"
    EOT
  }
}

# ------------------------------------------------------------------------------
# Upload the built Layer ZIP to AWS
# ------------------------------------------------------------------------------

resource "aws_lambda_layer_version" "common_dependencies" {
  layer_name          = "${var.project_name}-common-dependencies-${var.environment}"
  description         = "Common Python dependencies: requests, boto3, python-dotenv"
  filename            = "${path.module}/.lambda_builds/common_layer.zip"
  source_code_hash    = filebase64sha256("${path.module}/.lambda_builds/common_layer.zip")
  compatible_runtimes = ["python3.12"]

  depends_on = [null_resource.build_lambda_layer]
}


# ------------------------------------------------------------------------------
# Testing to store the Layer ARN in 
# SSM Parameter Store for easy retrieval by Lambdas at runtime
# ------------------------------------------------------------------------------

resource "aws_ssm_parameter" "lambda_layer_arn" {
  name        = "/${var.project_name}/${var.environment}/lambda-layer-arn"
  description = "ARN of the Lambda Layer with common dependencies"
  type        = "String"
  value       = aws_lambda_layer_version.common_dependencies.arn

  tags = {
    Name = "${var.project_name}-layer-arn-${var.environment}"
  }
}
