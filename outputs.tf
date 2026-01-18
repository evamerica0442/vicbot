output "bot_server_public_ip" {
  description = "Public IP of the bot server"
  value       = aws_instance.bot_server.public_ip
}

output "bot_server_private_ip" {
  description = "Private IP of the bot server"
  value       = aws_instance.bot_server.private_ip
}

output "waha_public_ip" {
  description = "Public IP of the Waha server"
  value       = aws_instance.waha.public_ip
}

output "waha_private_ip" {
  description = "Private IP of the Waha server"
  value       = aws_instance.waha.private_ip
}

output "waha_url" {
  description = "Waha API URL (public)"
  value       = "http://${aws_instance.waha.public_ip}:3000"
}

output "waha_dashboard_login" {
  description = "Waha dashboard login credentials"
  value       = <<-EOT
    Dashboard URL: http://${aws_instance.waha.public_ip}:3000
    Username: admin
    Password: ${var.waha_dashboard_password}
    
    Swagger UI: http://${aws_instance.waha.public_ip}:3000/api
    Username: admin
    Password: ${var.waha_dashboard_password}
  EOT
  sensitive   = true
}

output "bot_webhook_url" {
  description = "Bot webhook URL (private)"
  value       = "http://${aws_instance.bot_server.private_ip}:4000/webhook"
}

output "database_endpoint" {
  description = "RDS database endpoint"
  value       = aws_db_instance.orders.endpoint
}

output "database_name" {
  description = "RDS database name"
  value       = aws_db_instance.orders.db_name
}

output "ssh_command_bot" {
  description = "SSH command to connect to bot server"
  value       = "ssh -i ~/.ssh/${var.key_pair_name}.pem ubuntu@${aws_instance.bot_server.public_ip}"
}

output "ssh_command_waha" {
  description = "SSH command to connect to Waha server"
  value       = "ssh -i ~/.ssh/${var.key_pair_name}.pem ubuntu@${aws_instance.waha.public_ip}"
}

output "configure_webhook_command" {
  description = "Command to configure webhook manually if needed"
  value       = <<-EOT
    curl -X POST http://${aws_instance.waha.public_ip}:3000/api/webhooks \
      -H "Content-Type: application/json" \
      -H "X-Api-Key: ${var.waha_api_key}" \
      -d '{
        "url": "http://${aws_instance.bot_server.private_ip}:4000/webhook",
        "events": ["message"],
        "session": "${var.waha_session}"
      }'
  EOT
  sensitive   = true
}
