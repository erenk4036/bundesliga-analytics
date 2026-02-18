# ==============================================================================
# LAMBDA LAYER - Common Python Dependencies
# ==============================================================================
# Structure inside the ZIP must be:
#   python/lib/python3.12/site-packages/<your_packages>/
# ==============================================================================

resource "null_resource" "build_lambda_layer" {
  triggers = {
    # Re-build the layer whenever requirements.txt changes
    requirements_hash = filemd5("${path.module}/layers/common/requirements.txt")
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "Building Lambda Layer..."

      # Clean up any previous build artifacts
      rm -rf ${path.module}/layers/common/python
      rm -f  ${path.module}/.lambda_builds/common_layer.zip

      # Create the directory structure Lambda expects
      mkdir -p ${path.module}/layers/common/python

      # Install packages into the layer directory
      # --platform: ensures Linux-compatible binaries even on Mac/Windows
      # --only-binary=:all: avoids compiling C extensions locally
      # --python-version: pins to our Lambda runtime version
      pip install \
        --platform manylinux2014_x86_64 \
        --only-binary=:all: \
        --python-version 3.12 \
        --target ${path.module}/layers/common/python \
        -r ${path.module}/layers/common/requirements.txt

      # Create the ZIP archive
      mkdir -p ${path.module}/.lambda_builds
      cd ${path.module}/layers/common && zip -r9 \
        ${path.module}/.lambda_builds/common_layer.zip python/

      echo "Layer build complete!"
    EOT
  }
}

# ------------------------------------------------------------------------------
# Upload the built Layer ZIP to AWS
# ------------------------------------------------------------------------------

resource "aws_lambda_layer_version" "common_dependencies" {
  layer_name  = "${var.project_name}-common-deps-${var.environment}"
  description = "Shared Python dependencies: requests, boto3 extensions, python-dotenv"

  filename         = "${path.module}/.lambda_builds/common_layer.zip"
  source_code_hash = filebase64sha256("${path.module}/.lambda_builds/common_layer.zip")

  # Declare which runtimes are compatible with this layer
  compatible_runtimes = ["python3.12"]

  # Ensure the build runs BEFORE Terraform tries to upload the ZIP
  depends_on = [null_resource.build_lambda_layer]
}


# ------------------------------------------------------------------------------
# Testing to store the Layer ARN in 
# SSM Parameter Store for easy retrieval by Lambdas at runtime
# ------------------------------------------------------------------------------

resource "aws_ssm_parameter" "lambda_layer_arn" {
  name        = "/${var.project_name}/${var.environment}/lambda/layer/common-deps/arn"
  description = "ARN of the shared Lambda dependency layer"
  type        = "String"
  value       = aws_lambda_layer_version.common_dependencies.arn

  tags = {
    Name = "${var.project_name}-layer-arn-param-${var.environment}"
  }
}
