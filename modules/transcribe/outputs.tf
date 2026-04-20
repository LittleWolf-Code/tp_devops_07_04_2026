output "transcribe_bucket_name" {
  description = "Name of the S3 bucket for Transcribe"
  value       = aws_s3_bucket.transcribe_bucket.bucket
}

output "transcribe_bucket_arn" {
  description = "ARN of the S3 bucket for Transcribe"
  value       = aws_s3_bucket.transcribe_bucket.arn
}
