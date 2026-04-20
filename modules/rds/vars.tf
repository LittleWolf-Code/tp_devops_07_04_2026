variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for the DB subnet group"
  type        = list(string)
}

variable "asg_sg_id" {
  description = "Security group ID of the ASG instances"
  type        = string
}

variable "db_username" {
  description = "Database master username"
  type        = string
  default     = "root"
}

variable "db_password" {
  description = "Database master password"
  type        = string
  sensitive   = true
}

variable "db_name" {
  description = "Name of the database"
  type        = string
  default     = "blog"
}
