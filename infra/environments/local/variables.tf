variable "aws_region" {
  description = "AWS region used for local emulation."
  type        = string
  default     = "us-east-1"
}

variable "floci_endpoint" {
  description = "Base URL of the Floci AWS endpoint."
  type        = string
  default     = "http://localhost:4566"
}
