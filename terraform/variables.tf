variable "aws_access_key" {
  description = "AWS access key"
  type        = string
  sensitive   = true
}

variable "aws_secret_key" {
  description = "AWS secret key"
  type        = string
  sensitive   = true
}

variable "region" {
  description = "The AWS region to deploy to"
  type        = string
}

variable "part" {
  description = "A part identifier for naming resources"
  type        = string
  default     = "1"  # You can change this default or set it at runtime
}
