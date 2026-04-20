# --- S3 Bucket for audio files and transcription outputs ---
resource "aws_s3_bucket" "transcribe_bucket" {
  bucket        = var.bucket_name
  force_destroy = true

  tags = {
    Name = "tp-transcribe-bucket"
  }
}
