output "name" {
  description = "Bucket name."
  value       = aws_s3_bucket.state.id
}

output "arn" {
  description = "Bucket ARN."
  value       = aws_s3_bucket.state.arn
}
