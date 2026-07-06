output "vpc_id" {
  value = module.vpc.vpc_id
}

output "public_subnet_id" {
  value = module.vpc.public_subnet_id
}

output "private_subnet_id" {
  value = module.vpc.private_subnet_id
}

output "data_subnet_id" {
  value = module.vpc.data_subnet_id
}

output "alb_sg_id" {
  value = module.vpc.alb_sg_id
}

output "app_sg_id" {
  value = module.vpc.app_sg_id
}

output "db_sg_id" {
  value = module.vpc.db_sg_id
}