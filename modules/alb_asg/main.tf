# --- Security Group for ASG instances ---
resource "aws_security_group" "asg_sg" {
  name        = "tp-asg-sg"
  description = "Allow traffic from ALB on port 80"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_allowed_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "tp-asg-sg"
  }
}

# --- Security Group for ALB ---
resource "aws_security_group" "alb_sg" {
  name        = "tp-alb-sg"
  description = "Allow HTTP traffic from internet"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "tp-alb-sg"
  }
}

# --- Target Group ---
resource "aws_lb_target_group" "app_tg" {
  name     = "tp-app-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    path                = "/index.php"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
  }

  tags = {
    Name = "tp-app-tg"
  }
}

# --- Application Load Balancer ---
resource "aws_lb" "app_alb" {
  name               = "tp-app-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = var.public_subnet_ids

  tags = {
    Name = "tp-app-alb"
  }
}

# --- HTTP Listener ---
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}

# --- SSH Key Pair ---
resource "aws_key_pair" "deployer" {
  key_name   = "tp-deployer-key"
  public_key = file(var.path_to_public_key)
}

# --- Launch Configuration ---
resource "aws_launch_configuration" "app_lc" {
  name_prefix          = "tp-app-lc-"
  image_id             = var.ami_id
  instance_type        = var.instance_type
  iam_instance_profile = var.instance_profile_name
  key_name             = aws_key_pair.deployer.key_name
  security_groups      = [aws_security_group.asg_sg.id]
  user_data            = var.user_data

  lifecycle {
    create_before_destroy = true
  }
}

# --- Auto Scaling Group ---
resource "aws_autoscaling_group" "app_asg" {
  name                 = "tp-app-asg"
  launch_configuration = aws_launch_configuration.app_lc.name
  vpc_zone_identifier  = var.private_subnet_ids
  target_group_arns    = [aws_lb_target_group.app_tg.arn]
  health_check_type         = "ELB"
  health_check_grace_period = 300
  force_delete              = true

  desired_capacity = var.desired_capacity
  min_size         = var.min_size
  max_size         = var.max_size

  tag {
    key                 = "Name"
    value               = "tp-web-instance"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}
