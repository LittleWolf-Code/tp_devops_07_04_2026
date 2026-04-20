variable "lab_role_name" {
  description = "Name of the pre-existing IAM role in AWS Academy"
  type        = string
  default     = "LabRole"
}

variable "lab_instance_profile_name" {
  description = "Name of the pre-existing instance profile in AWS Academy"
  type        = string
  default     = "LabInstanceProfile"
}
