# --- Scale Up Policy ---
resource "aws_autoscaling_policy" "scale_up" {
  name                   = "tp-scale-up-policy"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  policy_type            = "SimpleScaling"
  autoscaling_group_name = var.asg_name
}

# --- Scale Down Policy ---
resource "aws_autoscaling_policy" "scale_down" {
  name                   = "tp-scale-down-policy"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  policy_type            = "SimpleScaling"
  autoscaling_group_name = var.asg_name
}

# --- CloudWatch Alarm: High CPU (>= 80%) ---
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "tp-high-cpu-alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Scale up when CPU >= 80%"
  alarm_actions       = [aws_autoscaling_policy.scale_up.arn]

  dimensions = {
    AutoScalingGroupName = var.asg_name
  }
}

# --- CloudWatch Alarm: Low CPU (< 5%) ---
resource "aws_cloudwatch_metric_alarm" "low_cpu" {
  alarm_name          = "tp-low-cpu-alarm"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = 20
  alarm_description   = "Scale down when CPU <= 20%"
  alarm_actions       = [aws_autoscaling_policy.scale_down.arn]

  dimensions = {
    AutoScalingGroupName = var.asg_name
  }
}
