# Cloud Resume Challenge - Infrastructure Architecture

## Visual Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              Internet Users                                      │
│                         (Europe only - geo-restricted)                           │
└──────────────────────────────────┬──────────────────────────────────────────────┘
                                   │ HTTPS
                    ┌──────────────▼──────────────┐
                    │        Route53 (DNS)         │
                    │        vitraigabor.eu        │
                    │  • A/AAAA — vitraigabor.eu   │
                    │  • A/AAAA — resume.*         │
                    │  • A/AAAA — ik.*             │
                    │  • A/AAAA — gallery.*        │
                    └──────────────┬──────────────┘
                                   │
          ┌────────────────────────┼────────────────────────┐
          │                        │                        │
          ▼                        ▼                        ▼
┌──────────────────┐    ┌──────────────────┐    ┌──────────────────────┐
│   CloudFront     │    │   CloudFront     │    │   CloudFront         │
│   (Resume)       │    │   (IK Website)   │    │   (Gallery)          │
│                  │    │                  │    │                      │
│ vitraigabor.eu   │    │ ik.vitraigabor   │    │ gallery.vitraigabor  │
│ resume.*         │    │ .eu              │    │ .eu                  │
│                  │    │                  │    │                      │
│ CF Function:     │    │                  │    │ CF Function:         │
│ redirect root    │    │                  │    │ Basic Auth           │
└────────┬─────────┘    └────────┬─────────┘    └──────────┬───────────┘
         │                       │                          │
         ▼                       ▼                          ▼
┌──────────────────┐    ┌──────────────────┐    ┌──────────────────────┐
│   S3 Bucket      │    │   S3 Bucket      │    │   S3 Bucket          │
│   (Resume)       │    │   (IK Website)   │    │ (Photo Thumbnails)   │
│ vitraiaws-cloud  │    │ vitraiaws-ik-    │    │ vitraiaws-photos-    │
│ -resume-challenge│    │ website          │    │ backup-thumbnails    │
│ (Private, OAC)   │    │ (Private, OAC)   │    │ (Private, OAC)       │
└──────────────────┘    └──────────────────┘    └──────────────────────┘


┌──────────────────────────────────────────────────────────────────────┐
│                       Resume Backend                                  │
├──────────────────────────────────────────────────────────────────────┤
│                                                                      │
│   Lambda Function URL                    DynamoDB Table              │
│   (view counter - public)         →      cloud-resume-view-counter   │
│   Python 3.12 / CORS / Referer           (atomic increment)          │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────┐
│                       Supporting Services                             │
├──────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ACM Certificate (us-east-1)    IAM          CloudWatch / SNS        │
│  • *.vitraigabor.eu             • Roles      • Lambda logs           │
│  • Covers all subdomains        • Policies   • CloudFront alerts     │
│                                                                      │
│  S3 Terraform State Backend                                          │
│  • vitraiaws-cloud-resume-terraform-state (versioned, encrypted)     │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
```

## Hosted Subdomains

| Subdomain | Purpose | Auth | S3 Bucket |
|-----------|---------|------|-----------|
| `vitraigabor.eu` | Redirects → `resume.vitraigabor.eu` | None | — |
| `resume.vitraigabor.eu` | CV / cloud resume | None (public) | `vitraiaws-cloud-resume-challenge` |
| `ik.vitraigabor.eu` | University portfolio (Gumdrop SPA) | None (public) | `vitraiaws-ik-website` |
| `gallery.vitraigabor.eu` | Photo thumbnail gallery | HTTP Basic Auth | `vitraiaws-photos-backup-thumbnails` |

## Request Flows

### 1. Resume / IK Website
```
User Browser
    → Route53: resume.vitraigabor.eu  (or  ik.vitraigabor.eu)
    → CloudFront edge (EU)
    → S3 Bucket on cache miss (via OAC)
    → Returns static HTML/CSS/JS
```

### 2. Root domain redirect
```
User Browser
    → Route53: vitraigabor.eu
    → CloudFront (Resume distribution)
    → CloudFront Function: 301 → https://resume.vitraigabor.eu
```

### 3. Gallery
```
User Browser
    → Route53: gallery.vitraigabor.eu
    → CloudFront edge (EU)
    → CloudFront Function checks Authorization header (Basic Auth)
        ├─ Missing/wrong → 401 Unauthorized (browser shows login dialog)
        └─ Correct → request passes through
    → S3 Bucket on cache miss (thumbnails + gallery app files)
    → Gallery SPA loads manifest.json, builds folder tree
```

### 4. View Counter
```
JavaScript in Browser (resume only)
    → fetch() POST to Lambda Function URL
    → Lambda validates Origin/Referer
    → Lambda: DynamoDB UpdateItem (atomic increment)
    → Returns JSON { views: N }
    → JavaScript updates counter in sidebar
```

## Components

### Frontend Layer

| Component | Purpose | Key Details |
|-----------|---------|-------------|
| **Route53 Hosted Zone** | DNS management | A/AAAA alias records for all 4 subdomains |
| **CloudFront (Resume)** | CDN for resume | CF Function: root redirect; edge cache 1 week |
| **CloudFront (IK Website)** | CDN for portfolio | Hash-based SPA routing; 403/404 → index.html |
| **CloudFront (Gallery)** | CDN for photo gallery | CF Function: Basic Auth on viewer-request |
| **S3 (Resume)** | Resume static files | Private, versioned, encrypted, OAC access |
| **S3 (IK Website)** | IK portfolio files | Private, OAC access |
| **S3 (Photo Thumbnails)** | Gallery thumbnails + app | Existing bucket; Glacier Instant Retrieval |
| **ACM Certificate** | SSL/TLS | Wildcard `*.vitraigabor.eu`; us-east-1; auto-renewed |

### Backend Layer

| Component | Purpose | Key Details |
|-----------|---------|-------------|
| **Lambda Function** | View counter API | Python 3.12; Function URL; CORS + Referer validation |
| **DynamoDB Table** | Counter storage | Single item; on-demand billing; atomic increments |
| **IAM Role** | Lambda permissions | DynamoDB read/write + CloudWatch logs |
| **CloudWatch Logs** | Lambda logging | 7-day retention |

### CloudFront Functions

| Function | Distribution | Purpose |
|----------|-------------|---------|
| `cloud-resume-redirect-root` | Resume | 301 redirect `vitraigabor.eu` → `resume.vitraigabor.eu` |
| `gallery-basic-auth` | Gallery | HTTP Basic Auth gate on every viewer request |

## Gallery Deploy Flow

On every push to `main` in the frontend repo, GitHub Actions:
1. Generates `manifest.json` by listing the thumbnails S3 bucket (image keys only)
2. Syncs `gallery/` app files (HTML/CSS/JS) to the thumbnails bucket root
3. Uploads `manifest.json` to the thumbnails bucket
4. Invalidates `/index.html`, `/app.js`, `/app.css`, `/manifest.json` in CloudFront

The thumbnail images themselves are never modified by CI — they live permanently in S3.

## Security Features

### Network
- HTTPS only (HTTP → HTTPS redirect at CloudFront)
- Geo-restriction: Europe only on all distributions
- TLS 1.2 minimum
- All S3 buckets private (no public access); CloudFront accesses via OAC

### Authentication
- Gallery protected by HTTP Basic Auth (CloudFront Function)
- Credentials embedded in function code at deploy time via Terraform variable
- Security relies on HTTPS for credential confidentiality in transit

### API (Resume view counter)
- CORS: browser requests from `vitraigabor.eu` only
- Referer header validation in Lambda

### Infrastructure
- Terraform state encrypted at rest (S3 + SSE)
- S3 versioning on resume bucket and state bucket
- IAM least-privilege (separate policies per role/purpose)
- No hardcoded credentials in version control
- SSO authentication (IAM Identity Center, MFA enabled)

## Cost Breakdown

| Service | Monthly Cost | Notes |
|---------|--------------|-------|
| **Route53 Hosted Zone** | $0.50 | Fixed cost for the hosted zone |
| **CloudFront (3 distributions)** | FREE | Well within 1TB/month free tier |
| **CloudFront Functions** | FREE | 2M free invocations/month per function |
| **S3 (Resume + IK buckets)** | FREE | ~20KB each, negligible |
| **S3 (Thumbnails - Glacier IR)** | ~$0.004/GB/month | Retrieval: $0.03/GB on cache miss |
| **Lambda** | FREE | Within free tier (1M requests/month) |
| **DynamoDB** | FREE | Within free tier |
| **ACM Certificate** | FREE | Always free |
| **CloudWatch Logs** | FREE | Within free tier |
| **Domain Registration** | $8–13/year | Annual renewal |
| **TOTAL** | **~$0.50/month** | Dominated by Route53 hosted zone |

## Regions

- **Primary**: `eu-west-1` (Ireland) — S3, Lambda, DynamoDB, CloudWatch
- **Certificate**: `us-east-1` (N. Virginia) — ACM (CloudFront requirement)
- **Global**: CloudFront edge locations, Route53, IAM Identity Center

## Terraform File Structure

```
cloud-resume-challenge-iac/
├── provider.tf           # AWS provider config (eu-west-1 + us-east-1)
├── backend.tf            # S3 remote state
├── variables.tf          # Input variables (region, domain, alert_email, gallery_auth_credentials)
├── main.tf               # Resume S3 bucket
├── website.tf            # S3 objects (HTML/CSS/JS uploads)
├── cloudfront.tf         # Resume CloudFront distribution + root-redirect CF Function
├── ik-website.tf         # IK website S3 bucket + CloudFront distribution
├── gallery.tf            # Gallery S3 bucket policy + CloudFront distribution + Basic Auth CF Function
├── route53.tf            # DNS records (A/AAAA for all 4 subdomains)
├── acm.tf                # Wildcard SSL certificate (us-east-1)
├── dynamodb.tf           # View counter table
├── lambda.tf             # Lambda function + IAM role + Function URL + CloudWatch
├── monitoring.tf         # SNS alerts + EventBridge CloudFront API monitoring
├── outputs.tf            # Output values (URLs, distribution IDs, etc.)
├── cloudfront-functions/
│   ├── redirect_root_to_resume.js  # Root domain redirect
│   └── gallery-basic-auth.js       # Gallery Basic Auth (Terraform templatefile)
├── lambda/
│   └── view_counter.py             # Lambda function code
└── docs/
    └── iam-policies/               # Reference copies of all IAM policies
```

## Architecture Patterns

- **Serverless**: No EC2 instances; Lambda + managed services only
- **Infrastructure as Code**: All resources defined in Terraform
- **Static Site Hosting**: Pre-built HTML/CSS/JS served from S3 via CloudFront
- **Multi-site from single IaC repo**: Three independent sites, one Terraform project
- **Least Privilege IAM**: Separate policies scoped per role and per bucket/resource
- **Immutable infrastructure**: Replace resources rather than modifying in place
