output "frontend_public_ip" {
  description = "Browse to this IP to use the app"
  value       = module.frontend_ec2.public_ip
}

output "backend_private_ip" {
  value = module.backend_ec2.private_ip
}

output "backend_instance_id" {
  description = "Used by the app-deploy pipeline's SSM Run Command"
  value       = module.backend_ec2.instance_id
}

output "frontend_instance_id" {
  description = "Used by the app-deploy pipeline's SSM Run Command"
  value       = module.frontend_ec2.instance_id
}

output "rds_endpoint" {
  value = module.rds.endpoint
}

output "frontend_vpc_id" {
  value = module.frontend_vpc.vpc_id
}

output "backend_vpc_id" {
  value = module.backend_vpc.vpc_id
}

output "database_vpc_id" {
  value = module.database_vpc.vpc_id
}
