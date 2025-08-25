output "s3_bucket_name" {
  description = "Name S3-bucket"
  value = module.s3_backend.s3_bucket_name
}

output "s3_bucket_url" {
  description = "URL S3-bucket"
  value = module.s3_backend.s3_bucket_url
}

output "vpc_id" {
  description = "ID VPC"
  value = module.vpc.vpc_id
}

output "private_subnets" {
  description = "Private Subnets"
  value = module.vpc.private_subnets
}
output "public_subnets" {
  description = "Public Subnets"
  value = module.vpc.public_subnets
}

output "ecr_repository_url" {
  description = "Repository URL"
  value = module.ecr.ecr_repository_url
}
