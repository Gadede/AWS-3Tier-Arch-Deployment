output "web_asg_name" {
  description = "Name of the web tier Auto Scaling Group"
  value       = aws_autoscaling_group.web.name
}

output "app_asg_name" {
  description = "Name of the app tier Auto Scaling Group"
  value       = aws_autoscaling_group.app.name
}

output "web_launch_template_id" {
  description = "ID of the web tier launch template"
  value       = aws_launch_template.web-tier.id
}

output "app_launch_template_id" {
  description = "ID of the app tier launch template"
  value       = aws_launch_template.app-tier.id
}