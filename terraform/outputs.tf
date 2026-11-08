# -----------
# OUTPUTS
# -----------

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "alb_dns_name" {
  description = "ALB DNS name"
  value       = aws_lb.main.dns_name
}

output "bastion_public_ip" {
  description = "BASTION Public IP"
  value       = aws_instance.bastion-host.public_ip
}

output "backend_private_ip" {
  description = "BACKEND Private IP"
  value       = [for instance in aws_instance.backend-server : instance.private_ip]
}
