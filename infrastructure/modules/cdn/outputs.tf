output "url" {
  description = "Public URL of the lab."
  value       = "https://${aws_cloudfront_distribution.this.domain_name}"
}

output "domain_name" {
  description = "CloudFront domain name, without the scheme."
  value       = aws_cloudfront_distribution.this.domain_name
}

output "distribution_id" {
  description = "ID of the distribution, for invalidations."
  value       = aws_cloudfront_distribution.this.id
}

output "frontend_bucket" {
  description = "Bucket the frontend build is uploaded to."
  value       = aws_s3_bucket.frontend.id
}
