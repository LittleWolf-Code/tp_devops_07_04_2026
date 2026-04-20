variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "db_password" {
  description = "Password for the RDS database"
  type        = string
  sensitive   = true
}

variable "db_username" {
  description = "Username for the RDS database"
  type        = string
  default     = "root"
}

variable "bucket_name" {
  description = "Name of the S3 bucket (must be globally unique)"
  type        = string
  default     = "tp-devops-app-sources-2026"
}

variable "path_to_public_key" {
  description = "Path to the SSH public key"
  type        = string
  default     = "./keys/terraform.pub"
}

variable "ami_id" {
  description = "AMI ID for EC2 instances (Amazon Linux 2 in us-east-1)"
  type        = string
  default     = "ami-0c02fb55956c7d316"
}

variable "transcribe_bucket_name" {
  description = "Name of the S3 bucket for AWS Transcribe audio files"
  type        = string
  default     = "tp-devops-transcribe-audio-2026"
}