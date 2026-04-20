output "instance_profile_name" {
  description = "Name of the instance profile"
  value       = data.aws_iam_instance_profile.lab_profile.name
}

output "role_arn" {
  description = "ARN of the IAM role"
  value       = data.aws_iam_role.lab_role.arn
}

output "role_name" {
  description = "Name of the IAM role"
  value       = data.aws_iam_role.lab_role.name
}
