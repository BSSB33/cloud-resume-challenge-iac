locals {
  website_path = "../cloud-resume-challenge-website"

  # MIME type mapping
  mime_types = {
    ".html" = "text/html"
    ".css"  = "text/css"
    ".js"   = "application/javascript"
    ".json" = "application/json"
    ".jpg"  = "image/jpeg"
    ".jpeg" = "image/jpeg"
    ".png"  = "image/png"
    ".gif"  = "image/gif"
    ".svg"  = "image/svg+xml"
    ".ico"  = "image/x-icon"
    ".txt"  = "text/plain"
    ".pdf"  = "application/pdf"
  }

  # Files to upload
  website_files = {
    "index.html"                    = "index.html"
    "styles.css"                    = "styles.css"
    "script.js"                     = "script.js"
    "resources/profile_picture.JPG" = "resources/profile_picture.JPG"
  }
}

# Upload website files to S3
resource "aws_s3_object" "website_files" {
  for_each = local.website_files

  bucket       = aws_s3_bucket.cloud_resume.id
  key          = each.value
  source       = "${local.website_path}/${each.key}"
  content_type = lookup(local.mime_types, regex("\\.[^.]+$", each.key), "application/octet-stream")
  etag         = filemd5("${local.website_path}/${each.key}")

  # Cache control headers for CloudFront
  cache_control = each.key == "index.html" ? "max-age=300, must-revalidate" : "max-age=31536000, immutable"

  tags = {
    Name         = each.value
    cloud-resume = "true"
  }
}
