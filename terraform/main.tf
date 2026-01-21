provider "aws" {
  region = var.aws_region
}

# Get current account number
data "aws_caller_identity" "current" {}

#
#
# S3 Buckets
#
#
resource "aws_s3_bucket" "worload_bucket" {
  bucket = var.s3_bucket_name
  force_destroy = true

  lifecycle {
    prevent_destroy = false
  }
}

# disable S3 versioning to reduce storage costs and prevent unintended sensible data retention
resource "aws_s3_bucket_versioning" "worload_bucket_versioning" {
  bucket = aws_s3_bucket.worload_bucket.id
  
  versioning_configuration {
    status = "Suspended"
  }
}

resource "aws_s3_bucket_ownership_controls" "worload_bucket_ownership" {
  bucket = aws_s3_bucket.worload_bucket.id
  
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# Enable Server Side Encryption with AES256
resource "aws_s3_bucket_server_side_encryption_configuration" "worload_bucket_sse" {
    bucket = aws_s3_bucket.worload_bucket.id

    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
}

# add Block Puclic Access to S3 Bucket to protect against public access and future misconfiguration
resource "aws_s3_bucket_public_access_block" "worload_bucket_public_access_block" {
  bucket = aws_s3_bucket.worload_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}



# S3 Bucket policy deny non TLS requests, explicitly deny public access.
resource "aws_s3_bucket_policy" "worload_bucket_policy" {
  
  bucket = aws_s3_bucket.worload_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyNonTLSRequests"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.worload_bucket.arn,
          "${aws_s3_bucket.worload_bucket.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]      
  })
}
