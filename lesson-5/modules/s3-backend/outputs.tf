output "s3_bucket_name" {
  description = "Назва S3-бакета для стейтів"
  value       = aws_s3_bucket.terraform_state.bucket
}

output "dynamodb_table_name" {
  description = "URL of the created S3 bucket"
  value       = aws_dynamodb_table.terraform_locks.name
}

output "s3_bucket_url" {
  description = "Назва таблиці DynamoDB для блокування стейтів"
  value = "https://${aws_s3_bucket.terraform_state.bucket_domain_name}"
}

