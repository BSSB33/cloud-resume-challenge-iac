# Cloud Resume Challenge - Infrastructure Architecture

## Visual Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                           Internet Users                            │
│                      (Europe only - geo-restricted)                 │
└────────────────────────────────┬────────────────────────────────────┘
                                 │
                                 │ HTTPS
                                 │
                    ┌────────────▼─────────────┐
                    │                          │
                    │   Route53 (DNS)          │
                    │   vitraigabor.eu         │
                    │   • A/AAAA Records       │
                    │                          │
                    └────────────┬─────────────┘
                                 │
                                 │
                    ┌────────────▼─────────────────────────────────┐
                    │                                              │
                    │        CloudFront Distribution               │
                    │        • SSL/TLS (ACM Certificate)           │
                    │        • Edge Caching (1 week)               │
                    │        • HTTPS Only                          │
                    │        • Price Class 100 (EU + NA)           │
                    │                                              │
                    └───────────┬──────────────────────────────────┘
                                │
                ┌───────────────┴───────────────┐
                │                               │
                │                               │
    ┌───────────▼──────────┐        ┌──────────▼──────────┐
    │                      │        │                      │
    │   S3 Bucket          │        │  Lambda Function URL │
    │   Origin             │        │  (Public)            │
    │                      │        │                      │
    │   • index.html       │        │  • Python 3.12       │
    │   • styles.css       │        │  • View Counter      │
    │   • script.js        │        │  • CORS Enabled      │
    │   • profile_pic.JPG  │        │                      │
    │                      │        └──────────┬───────────┘
    │   • Versioned        │                   │
    │   • Encrypted        │                   │ Read/Write
    │   • Private          │                   │
    │     (OAC access)     │        ┌──────────▼───────────┐
    │                      │        │                      │
    └──────────────────────┘        │   DynamoDB Table     │
                                    │                      │
                                    │   • id: "1" (S)      │
                                    │   • views: N         │
                                    │                      │
                                    │   • On-demand        │
                                    │   • Encrypted        │
                                    │                      │
                                    └──────────────────────┘


┌──────────────────────────────────────────────────────────────────────┐
│                     Supporting Services                              │
├──────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  IAM                          ACM                    CloudWatch      │
│  • Lambda Role               • SSL Certificate      • Lambda Logs   │
│  • DynamoDB Policy           • us-east-1            • 7-day retain  │
│  • CloudWatch Policy         • Auto-renewed         │               │
│                                                                      │
│  S3 Backend                                                          │
│  • State Storage (vitraiaws-cloud-resume-terraform-state)           │
│  • Versioned                                                         │
│  • Encrypted                                                         │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
```

## Request Flow

### 1. **User Visits Website**
```
User Browser
    ↓
    → Route53 DNS lookup: vitraigabor.eu
    ↓
    → CloudFront (Edge Location - EU)
    ↓
    → S3 Bucket (if cached miss)
    ↓
    → Returns: index.html, styles.css, script.js, images
    ↓
User Browser renders page
```

### 2. **View Counter Updates**
```
JavaScript in Browser
    ↓
    → fetch() POST to Lambda Function URL
    ↓
    → Lambda validates Origin/Referer
    ↓
    → Lambda calls DynamoDB UpdateItem (atomic increment)
    ↓
    → DynamoDB returns new count
    ↓
    → Lambda returns JSON response
    ↓
JavaScript updates counter in sidebar
```

## Components Breakdown

### Frontend Layer

| Component | Purpose | Key Features |
|-----------|---------|--------------|
| **Route53 Hosted Zone** | DNS management | • A/AAAA records<br>• Points to CloudFront |
| **CloudFront Distribution** | CDN & HTTPS | • Global edge caching<br>• SSL termination<br>• Origin Access Control |
| **S3 Bucket** | Static hosting | • Private bucket<br>• Versioned<br>• Encrypted |
| **ACM Certificate** | SSL/TLS | • Free certificate<br>• Auto-renewal<br>• us-east-1 region |

### Backend Layer

| Component | Purpose | Key Features |
|-----------|---------|--------------|
| **Lambda Function** | View counter API | • Python 3.12<br>• Function URL<br>• CORS enabled |
| **DynamoDB Table** | Counter storage | • Single item<br>• On-demand billing<br>• Atomic updates |
| **IAM Role** | Lambda permissions | • DynamoDB read/write<br>• CloudWatch logs |
| **CloudWatch Logs** | Lambda logging | • 7-day retention<br>• Debugging |

### Infrastructure Layer

| Component | Purpose | Key Features |
|-----------|---------|--------------|
| **Terraform State (S3)** | State management | • Remote backend<br>• Versioned<br>• Encrypted |
| **IAM Identity Center** | Authentication | • SSO login<br>• Temporary credentials<br>• MFA enabled |

## Security Features

### Network Security
- ✅ HTTPS only (HTTP → HTTPS redirect)
- ✅ Geo-restriction (Europe only)
- ✅ TLS 1.2 minimum
- ✅ S3 bucket private (no public access)
- ✅ Origin Access Control (CloudFront → S3)

### API Security
- ✅ CORS (browser-only from vitraigabor.eu)
- ✅ Referer header validation
- ⚠️ Lambda Function URL is public (can be called directly)

### Infrastructure Security
- ✅ Terraform state encrypted
- ✅ S3 versioning enabled
- ✅ IAM least privilege
- ✅ No hardcoded credentials
- ✅ SSO authentication

## Cost Breakdown

| Service | Monthly Cost | Notes |
|---------|--------------|-------|
| **Route53 Hosted Zone** | $0.50 | Only real cost |
| **CloudFront** | FREE | Within free tier (1TB) |
| **S3 Storage** | FREE | ~$0.001 (20KB site) |
| **Lambda** | FREE | Within free tier (1M requests) |
| **DynamoDB** | FREE | Within free tier |
| **ACM Certificate** | FREE | Always free |
| **CloudWatch Logs** | FREE | Within free tier |
| **Domain Registration** | $8-13/year | One-time annual |
| **TOTAL** | **~$0.50/month** | |

## Regions Used

- **Primary Region**: `eu-west-1` (Ireland)
  - S3 Bucket
  - Lambda Function
  - DynamoDB Table
  - CloudWatch Logs

- **Global Services**:
  - CloudFront (edge locations worldwide, price class 100)
  - Route53 (global DNS)
  - IAM Identity Center

- **Certificate Region**: `us-east-1` (N. Virginia)
  - ACM Certificate (CloudFront requirement)

## Tags

All resources tagged with:
```
cloud-resume = "true"
```

This allows easy cost tracking, resource grouping, and cleanup.

## Data Flow Summary

1. **Static Content**: User → Route53 → CloudFront → S3 → CloudFront (cached) → User
2. **Dynamic Content**: User → Lambda Function URL → Lambda → DynamoDB → Lambda → User
3. **Deployments**: Developer → Terraform → AWS Services
4. **State Management**: Terraform → S3 Backend (encrypted, versioned)

## Terraform Modules

```
cloud-resume-challenge-iac/
├── provider.tf          # AWS provider config (eu-west-1, us-east-1)
├── backend.tf           # S3 remote state
├── variables.tf         # Input variables
├── main.tf              # S3 bucket
├── website.tf           # S3 objects (HTML/CSS/JS)
├── cloudfront.tf        # CDN distribution
├── route53.tf           # DNS records
├── acm.tf               # SSL certificate
├── dynamodb.tf          # View counter table
├── lambda.tf            # Lambda function + IAM
├── outputs.tf           # Output values
└── lambda/
    └── view_counter.py  # Lambda code
```

## Architecture Patterns Used

✅ **Serverless**: No EC2 instances to manage
✅ **Infrastructure as Code**: Everything in Terraform
✅ **Static Site Generation**: Pre-built HTML/CSS/JS
✅ **Microservices**: Lambda for specific function
✅ **Immutable Infrastructure**: Replace, don't modify
✅ **Single Responsibility**: Each component has one job
✅ **Least Privilege**: IAM policies minimal permissions

## Future Improvements

Potential enhancements:
- [ ] Add WAF for DDoS protection
- [ ] Implement Lambda@Edge for dynamic content
- [ ] Add CloudFront signed URLs for Lambda
- [ ] Implement CI/CD pipeline (GitHub Actions)
- [ ] Add monitoring/alerting (CloudWatch Alarms)
- [ ] Add backup strategy for DynamoDB
- [ ] Implement blue/green deployments
