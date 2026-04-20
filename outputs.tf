output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = module.my_alb_asg.alb_dns_name
}

output "rds_endpoint" {
  description = "Endpoint of the RDS instance"
  value       = module.my_rds.db_host
}

output "transcribe_bucket_name" {
  description = "Name of the S3 bucket for AWS Transcribe"
  value       = module.my_transcribe.transcribe_bucket_name
}
