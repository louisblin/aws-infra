resource "aws_s3_bucket" "terraform_state" {
  bucket = "llb-tfstate"

  # Enable versioning to keep the full revision history
  versioning {
    enabled = true
  }

  lifecycle {
    prevent_destroy = true
  }

  # Enable server-side encryption at rest
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
}
