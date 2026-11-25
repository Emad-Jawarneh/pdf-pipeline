terraform {
  required_version = ">= 1.5, < 2.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  s3_use_path_style           = true
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  endpoints {
    dynamodb    = var.floci_endpoint
    eventbridge = var.floci_endpoint
    lambda      = var.floci_endpoint
    s3          = var.floci_endpoint
    sqs         = var.floci_endpoint
  }
}
