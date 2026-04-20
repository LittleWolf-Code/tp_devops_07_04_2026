resource "aws_s3_bucket" "app_bucket" {
  bucket        = var.bucket_name
  force_destroy = true

  tags = {
    Name = "tp-s3-bucket"
  }
}

resource "aws_s3_object" "index_php" {
  bucket = aws_s3_bucket.app_bucket.id
  key    = "index.php"
  source = "${var.src_path}/index.php"
  etag   = filemd5("${var.src_path}/index.php")
}

resource "aws_s3_object" "db_config_php" {
  bucket = aws_s3_bucket.app_bucket.id
  key    = "db-config.php"
  source = "${var.src_path}/db-config.php"
  etag   = filemd5("${var.src_path}/db-config.php")
}

resource "aws_s3_object" "validation_php" {
  bucket = aws_s3_bucket.app_bucket.id
  key    = "validation.php"
  source = "${var.src_path}/validation.php"
  etag   = filemd5("${var.src_path}/validation.php")
}

resource "aws_s3_object" "articles_sql" {
  bucket = aws_s3_bucket.app_bucket.id
  key    = "articles.sql"
  source = "${var.src_path}/articles.sql"
  etag   = filemd5("${var.src_path}/articles.sql")
}

resource "aws_s3_object" "transcribe_php" {
  bucket = aws_s3_bucket.app_bucket.id
  key    = "transcribe.php"
  source = "${var.src_path}/transcribe.php"
  etag   = filemd5("${var.src_path}/transcribe.php")
}
