# Cloud Resume Challenge - Infrastructure as Code

A fully serverless resume website built on AWS, deployed using Infrastructure as Code with Terraform and CloudFormation.

![AWS](https://img.shields.io/badge/AWS-%23FF9900.svg?style=flat&logo=amazon-aws&logoColor=white)
![Terraform](https://img.shields.io/badge/terraform-%235835CC.svg?style=flat&logo=terraform&logoColor=white)
![CloudFormation](https://img.shields.io/badge/CloudFormation-FF4F00?style=flat&logo=amazon-aws&logoColor=white)
![Python](https://img.shields.io/badge/python-3670A0?style=flat&logo=python&logoColor=ffdd54)

## 🌐 Live Demo

Visit the live website: [vitraigabor.eu](https://vitraigabor.eu)

## 🏗️ Architecture

This project implements a modern serverless architecture on AWS:

```
User → Route53 → CloudFront → S3 (Static Website)
                            ↓
                    Lambda Function URL → DynamoDB (View Counter)
                                       ↓
                                       DynamoDB (Rate Limiting)
```

### Services Used

- **S3** - Static website hosting (HTML, CSS, JS, images)
- **CloudFront** - CDN with SSL/TLS and edge caching
- **Route53** - DNS management
- **ACM** - SSL/TLS certificate (free, auto-renewed)
- **Lambda** - Serverless view counter API (Python 3.12)
- **DynamoDB** - NoSQL database for view count storage
- **IAM** - Security and permissions
- **CloudWatch** - Logging and monitoring

## 🚀 Quick Start

### Prerequisites

- AWS Account with IAM Identity Center (SSO) configured
- AWS CLI configured with profile: `vitraigabor`
- Terraform >= 1.0
- Domain name with Route53 hosted zone

### Deploy with Terraform

```bash
# Clone the repository
git clone <repository-url>
cd cloud-resume-challenge-iac

# Initialize Terraform
terraform init

# Review planned changes
terraform plan

# Deploy infrastructure
terraform apply

# Upload website files (if needed)
# Files are managed by Terraform in website.tf
```

### Deploy with CloudFormation

See [CLOUDFORMATION-README.md](CLOUDFORMATION-README.md) for detailed CloudFormation deployment instructions.

## 📁 Project Structure

```
.
├── README.md                    # This file
├── ARCHITECTURE.md              # Detailed architecture documentation
├── CLAUDE.md                    # AI assistant context
├── CLOUDFORMATION-README.md     # CloudFormation deployment guide
│
├── provider.tf                  # AWS provider configuration
├── backend.tf                   # S3 remote state backend
├── variables.tf                 # Input variables
├── outputs.tf                   # Output values
│
├── main.tf                      # S3 bucket for website
├── website.tf                   # Website files (HTML/CSS/JS)
├── cloudfront.tf                # CDN distribution
├── route53.tf                   # DNS records
├── acm.tf                       # SSL certificate
├── lambda.tf                    # Lambda function + IAM
├── dynamodb.tf                  # View counter table
│
├── lambda/
│   └── view_counter.py          # Python Lambda function
│
├── template.yaml                # CloudFormation template
└── template-composer.yaml       # AWS Application Composer template
```

## 🎯 Features

### Infrastructure
- ✅ 100% Infrastructure as Code (Terraform + CloudFormation)
- ✅ Remote state management (S3 backend)
- ✅ Multi-region deployment (eu-west-1 + us-east-1 for ACM)
- ✅ Modular Terraform configuration

### Security
- ✅ HTTPS only (HTTP redirects to HTTPS)
- ✅ Private S3 bucket with Origin Access Control (OAC)
- ✅ Geo-restriction (Europe only)
- ✅ TLS 1.2 minimum
- ✅ CORS protection on Lambda
- ✅ IAM least privilege
- ✅ Encryption at rest (S3, DynamoDB, Terraform state)
-  IP-based rate limiting (1 increment/hour per IP)
-  Client-side session tracking to prevent spam

### Performance
- ✅ Global CDN with edge caching (CloudFront)
- ✅ Serverless architecture (Lambda + DynamoDB)
- ✅ On-demand scaling
- ✅ 1-week cache TTL for static content

### Cost Optimization
- ✅ ~$0.50/month total cost (only Route53 hosted zone)
- ✅ All services within AWS Free Tier
- ✅ On-demand billing for Lambda and DynamoDB
- ✅ CloudFront Price Class 100 (EU + NA only)

##  View Counter Rate Limiting

The view counter implements a **layered defense strategy** to prevent abuse:

### Client-Side Protection (Layer 1)
- Uses `sessionStorage` to track unique browser sessions
- Only increments counter on first visit within a session
- Prevents accidental refresh spam from legitimate users
- Bypassed by closing tab or incognito mode

### Server-Side IP Rate Limiting (Layer 2)
- Tracks visitor IPs in DynamoDB `cloud-resume-visitor-rate-limits` table
- **Rate limit:** 1 increment per IP per hour (3600 seconds)
- Automatic cleanup via DynamoDB TTL (24-hour expiration)
- Protection against bot attacks and malicious scripts

### How It Works
```
1. User visits page → Frontend checks sessionStorage
   → Already counted this session? → Show count only
   → New session? → Request increment

2. Lambda receives request → Extract client IP
   → Check rate limit table
   → IP incremented < 1 hour ago? → Return current count
   → IP not rate limited? → Increment counter + update rate limit
```

##  Common Operations

### Update Website Content

```bash
# Edit HTML/CSS/JS files locally
# Update website.tf with new content

# Apply changes
terraform apply

# Invalidate CloudFront cache (if needed)
aws cloudfront create-invalidation \
  --distribution-id <DISTRIBUTION_ID> \
  --paths "/*" \
  --profile vitraigabor
```

### Modify Lambda Function

```bash
# Edit lambda/view_counter.py

# Terraform will automatically repackage and deploy
terraform apply
```

### View Lambda Logs

```bash
# Tail logs in real-time
aws logs tail /aws/lambda/cloud-resume-view-counter \
  --follow \
  --profile vitraigabor
```

### Check DynamoDB View Count

```bash
aws dynamodb get-item \
  --table-name cloud-resume-view-counter \
  --key '{"id":{"S":"1"}}' \
  --profile vitraigabor
```

## 📊 Outputs

After deployment, Terraform provides:

- `website_bucket_name` - S3 bucket for website files
- `cloudfront_distribution_id` - CloudFront distribution ID
- `cloudfront_domain_name` - CloudFront domain
- `website_url` - Your website URL
- `lambda_function_url` - Lambda Function URL for API
- `dynamodb_table_name` - DynamoDB table name

## 🔧 Configuration

### Variables

Edit `variables.tf` or use `-var` flags:

```hcl
variable "aws_region" {
  default = "eu-west-1"
}

variable "environment" {
  default = "production"
}

variable "domain_name" {
  default = "vitraigabor.eu"
}
```

### Tags

All resources are tagged with:
- `cloud-resume = "true"`
- `Project = "cloud-resume-challenge"`
- `ManagedBy = "Terraform"` (or `CloudFormation`)
- `Environment = "production"`

## 💰 Cost Breakdown

| Service | Monthly Cost | Notes |
|---------|--------------|-------|
| Route53 Hosted Zone | $0.50 | Only significant cost |
| CloudFront | FREE | Within free tier (1TB) |
| S3 Storage | FREE | ~$0.001 for 20KB site |
| Lambda | FREE | Within free tier (1M requests) |
| DynamoDB | FREE | Within free tier |
| ACM Certificate | FREE | Always free |
| **Total** | **~$0.50/month** | + $8-13/year domain |

## 📚 Documentation

- [ARCHITECTURE.md](ARCHITECTURE.md) - Detailed architecture diagram and flow
- [CLAUDE.md](CLAUDE.md) - AI assistant context for development
- [CLOUDFORMATION-README.md](CLOUDFORMATION-README.md) - CloudFormation deployment guide

## 🎓 Learning Resources

This project implements the [Cloud Resume Challenge](https://cloudresumechallenge.dev/):
- Infrastructure as Code
- Serverless architecture
- CI/CD principles
- Cloud security best practices
- Cost optimization

## 🤝 Contributing

This is a personal project for the Cloud Resume Challenge, but suggestions and improvements are welcome!

## 📝 License

This project is open source and available under the MIT License.

## 👤 Author

**Gabor Vitrai**
- Website: [vitraigabor.eu](https://vitraigabor.eu)
- GitHub: [@gabor-sd](https://github.com/gabor-sd)

## 🙏 Acknowledgments

- [The Cloud Resume Challenge](https://cloudresumechallenge.dev/) by Forrest Brazeal
- AWS for providing free tier resources
- HashiCorp for Terraform

---

**Note:** This project uses AWS IAM Identity Center (SSO) with the profile `vitraigabor`. Update the profile name in `provider.tf` and `backend.tf` to match your configuration.
