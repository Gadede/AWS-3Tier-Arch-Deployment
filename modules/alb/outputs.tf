output "aws_lb_target_group_webtier_arn" {
  description = "ARN of the ALB target group for the web tier"
  value       = aws_lb_target_group.webtier.arn
  
}

output "aws_lb_target_group_apptier_arn" {
  description = "ARN of the ALB target group for the app tier"
  value       = aws_lb_target_group.apptier.arn
}

output "aws_lb_public_arn" {
  description = "ARN of the Web tier public ALB"
  value       = aws_lb.public.arn
  
}

output "webtier_target_group_arn" {
  value = aws_lb_target_group.webtier.arn
}

output "internal_alb_dns" {
  value = aws_lb.internal.dns_name
}

output "apptier_target_group_arn" {
  value = aws_lb_target_group.apptier.arn
}
