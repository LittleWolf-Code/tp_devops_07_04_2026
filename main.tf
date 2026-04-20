terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# --- VPC Module ---
module "my_vpc" {
  source = "./modules/vpc"
}

# --- S3 Module ---
module "my_s3" {
  source      = "./modules/s3"
  bucket_name = var.bucket_name
  src_path    = "${path.module}/src"
}

# --- EC2 Role Allow S3 Module ---
module "my_ec2_role_allow_s3" {
  source = "./modules/ec2_role_allow_s3"
}

# --- RDS Module ---
module "my_rds" {
  source             = "./modules/rds"
  vpc_id             = module.my_vpc.vpc_id
  private_subnet_ids = [module.my_vpc.private_subnet_1_id, module.my_vpc.private_subnet_2_id]
  asg_sg_id          = module.my_alb_asg.asg_sg_id
  db_username        = var.db_username
  db_password        = var.db_password
}

# --- ALB ASG Module ---
module "my_alb_asg" {
  source                = "./modules/alb_asg"
  vpc_id                = module.my_vpc.vpc_id
  public_subnet_ids     = [module.my_vpc.public_subnet_1_id, module.my_vpc.public_subnet_2_id]
  private_subnet_ids    = [module.my_vpc.private_subnet_1_id, module.my_vpc.private_subnet_2_id]
  ami_id                = var.ami_id
  instance_profile_name = module.my_ec2_role_allow_s3.instance_profile_name
  path_to_public_key    = var.path_to_public_key

  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    amazon-linux-extras install -y php7.4
    yum install -y httpd php php-mysqlnd mariadb

    systemctl start httpd
    systemctl enable httpd

    # Download app sources from S3
    aws s3 cp s3://${var.bucket_name}/index.php /var/www/html/index.php
    aws s3 cp s3://${var.bucket_name}/db-config.php /var/www/html/db-config.php
    aws s3 cp s3://${var.bucket_name}/validation.php /var/www/html/validation.php
    aws s3 cp s3://${var.bucket_name}/transcribe.php /var/www/html/transcribe.php
    aws s3 cp s3://${var.bucket_name}/articles.sql /tmp/articles.sql

    # Configure database connection
    sed -i 's/##DB_HOST##/${module.my_rds.db_host}/g' /var/www/html/db-config.php
    sed -i 's/##DB_USER##/${var.db_username}/g' /var/www/html/db-config.php
    sed -i 's/##DB_PASSWORD##/${var.db_password}/g' /var/www/html/db-config.php

    # Configure Transcribe bucket name and region
    sed -i 's/##TRANSCRIBE_BUCKET##/${var.transcribe_bucket_name}/g' /var/www/html/transcribe.php
    sed -i 's/##AWS_REGION##/${var.aws_region}/g' /var/www/html/transcribe.php

    # Initialize database
    mysql -h ${module.my_rds.db_host} -u ${var.db_username} -p'${var.db_password}' < /tmp/articles.sql

    systemctl restart httpd
  EOF
}

# --- AWS Transcribe Module ---
module "my_transcribe" {
  source      = "./modules/transcribe"
  bucket_name = var.transcribe_bucket_name
}

# --- CloudWatch CPU Alarms Module ---
module "my_cloudwatch_cpu_alarms" {
  source   = "./modules/cloudwatch_cpu_alarms"
  asg_name = module.my_alb_asg.asg_name
}
