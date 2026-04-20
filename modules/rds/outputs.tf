output "db_host" {
  description = "Endpoint of the RDS instance"
  value       = aws_db_instance.mariadb.address
}

output "db_name" {
  description = "Name of the database"
  value       = aws_db_instance.mariadb.db_name
}

output "db_username" {
  description = "Master username"
  value       = aws_db_instance.mariadb.username
}
