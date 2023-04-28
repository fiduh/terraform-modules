
output "distinct_subnet_in_az" {
  value = local.availability_zone_subnet
}


output "alb_dns_name" {
  value = aws_lb.example_alb.dns_name
  description = "The domain name of the load balancer"
}

output "asg_name" {
  value       = aws_autoscaling_group.example_asg.name
  description = "The name of the Auto Scaling Group"
}

output "alb_security_group_id" {
  value       = aws_security_group.alb_sg.id
  description = "The ID of the Security Group attached to the load balancer"
}