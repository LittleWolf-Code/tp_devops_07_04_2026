# --- Security Group for RDS ---
resource "aws_security_group" "rds_sg" {
  name        = "tp-rds-sg"
  description = "Allow traffic from web instances on port 3306"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [var.asg_sg_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "tp-rds-sg"
  }
}

# --- DB Subnet Group ---
resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "tp-rds-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = {
    Name = "tp-rds-subnet-group"
  }
}

# --- RDS MariaDB Instance ---
resource "aws_db_instance" "mariadb" {
  identifier              = "tp-mariadb"
  engine                  = "mariadb"
  engine_version          = "10.6"
  instance_class          = "db.t3.micro"
  allocated_storage       = 20
  max_allocated_storage   = 20
  db_name                 = var.db_name
  username                = var.db_username
  password                = var.db_password
  db_subnet_group_name    = aws_db_subnet_group.rds_subnet_group.name
  vpc_security_group_ids  = [aws_security_group.rds_sg.id]
  multi_az                = true
  backup_retention_period = 1
  skip_final_snapshot     = true

  tags = {
    Name = "tp-mariadb"
  }
}
