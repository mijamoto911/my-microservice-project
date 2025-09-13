output "ecr_repository_url" {
    description = "Full URL (hostname/names) for docker push/pull"
    value = aws_ecr_repository.ecr.repository_url
  
}
output "repository_arn" {
    description = "ARN created repository"
    value = aws_ecr_repository.ecr.arn
  
}