resource "aws_s3_bucket" "originals" {
  bucket = "pdf-pipeline-local-originals"
}

resource "aws_s3_bucket_public_access_block" "originals" {
  bucket = aws_s3_bucket.originals.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "originals" {
  bucket = aws_s3_bucket.originals.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

output "originals_bucket_name" {
  description = "Bucket for original PDF uploads in Floci."
  value       = aws_s3_bucket.originals.bucket
}

resource "aws_s3_bucket_notification" "originals" {
  bucket      = aws_s3_bucket.originals.id
  eventbridge = true

  depends_on = [aws_cloudwatch_event_target.processing]
}
