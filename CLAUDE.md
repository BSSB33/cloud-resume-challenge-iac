# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Cloud Resume Challenge infrastructure repository that deploys a set of serverless static websites on AWS, managed entirely with Terraform. It hosts **three sites** under `vitraigabor.eu`:

| Site | Purpose | Auth | S3 Bucket |
|------|---------|------|-----------|
| `vitraigabor.eu` | Redirects to `resume.vitraigabor.eu` (CloudFront Function) | None | — |
| `resume.vitraigabor.eu` | Resume / CV website with view counter | None (public) | `vitraiaws-cloud-resume-challenge` |
| `ik.vitraigabor.eu` | University portfolio (Gumdrop SPA) | None (public) | `vitraiaws-ik-website` |
| `gallery.vitraigabor.eu` | Photo thumbnail gallery | HTTP Basic Auth (CloudFront Function) | `vitraiaws-photos-backup-thumbnails` (data source, not managed here) |

Shared infrastructure: Route53, wildcard ACM certificate (`*.vitraigabor.eu`, us-east-1), Lambda + DynamoDB view counter with IP rate limiting, SNS/EventBridge monitoring. All resources deployed in `eu-west-1` (except ACM in `us-east-1` for CloudFront).

**Website content lives in a separate repository** (`cloud-resume-challenge-website`) and is deployed to the S3 buckets by that repo's GitHub Actions workflow — not by Terraform. This repo manages infrastructure only.

## Terraform Commands

### Basic Operations
```bash
# Initialize Terraform (downloads providers, configures S3 backend)
terraform init

# View planned changes
terraform plan

# Apply changes to AWS infrastructure
terraform apply

# Destroy all infrastructure
terraform destroy

# Format all .tf files
terraform fmt -recursive

# Validate configuration
terraform validate

# Show current state
terraform show

# List all resources in state
terraform state list
```

### Targeting Specific Resources
```bash
# Apply changes to only Lambda function
terraform apply -target=aws_lambda_function.view_counter

# Apply changes to only CloudFront distribution
terraform apply -target=aws_cloudfront_distribution.cloud_resume

# Destroy only DynamoDB table
terraform destroy -target=aws_dynamodb_table.view_counter
```

### State Management
```bash
# Refresh state from AWS
terraform refresh

# Pull remote state from S3
terraform state pull

# Remove resource from state (doesn't delete from AWS)
terraform state rm <resource_address>
```

## Architecture Overview

### Static Content Flow
1. User requests a site → Route53 DNS
2. Route53 → the site's CloudFront distribution (with SSL/TLS)
3. CloudFront Functions run at viewer-request:
   - Resume distribution: `redirect_root_to_resume` (301 from apex to `resume.`)
   - Gallery distribution: `gallery_auth` (HTTP Basic Auth, runs before cache lookup)
4. CloudFront → S3 bucket (via Origin Access Control)
5. CloudFront caches at edge (managed CachingOptimized policy) with managed SecurityHeadersPolicy response headers

### Dynamic Content Flow (view counter)
1. Browser JavaScript on the resume site calls the Lambda Function URL
2. Lambda validates Origin/Referer headers against `ALLOWED_ORIGINS`
3. Lambda checks IP rate limit (1 increment per hour per IP, `visitor_rate_limits` table with 24h TTL)
4. Only requests originating from `COUNTING_ORIGIN` (the resume subdomain) increment the counter
5. Lambda performs atomic increment on the DynamoDB item and returns the count as JSON

### Geo Restrictions
- Resume and IK distributions: whitelist of European countries
- Gallery distribution: whitelist of `HU` and `IT` only

### Multi-Provider Setup
The project uses **two AWS providers**:
- **Default provider**: `eu-west-1` for most resources (S3, Lambda, DynamoDB, CloudWatch, SNS)
- **Aliased provider**: `us-east-1` for ACM certificate (CloudFront requirement)

When modifying ACM resources, always use `provider = aws.us_east_1`.

Default tags (`Project`, `ManagedBy`, `Environment`) are applied via the provider; individual resources additionally carry `cloud-resume = "true"`, `ik-website = "true"`, or `gallery = "true"` tags.

## File Structure and Responsibilities

- `provider.tf` - AWS provider configuration (dual-region setup, default tags)
- `backend.tf` - S3 remote state configuration
- `variables.tf` - Input variables (region, domain, environment, `alert_email`, `gallery_auth_credentials`)
- `main.tf` - S3 bucket for the resume website
- `cloudfront.tf` - Resume CDN distribution, OAC, root-redirect function, bucket policy
- `ik-website.tf` - Complete IK site stack (S3 bucket, distribution, OAC, bucket policy)
- `gallery.tf` - Gallery stack (distribution, OAC, Basic Auth function, bucket policy; the thumbnails bucket itself is a `data` source managed outside Terraform)
- `cloudfront-functions/` - CloudFront Function source (`redirect_root_to_resume.js`, `gallery-basic-auth.js` — the latter is a `templatefile` with `${auth_credentials}` injected)
- `route53.tf` - DNS records (A/AAAA for apex, `resume.`, `ik.`; gallery records live in `gallery.tf`)
- `acm.tf` - Wildcard SSL certificate in us-east-1 + DNS validation
- `dynamodb.tf` - View counter table + visitor rate-limit table (TTL enabled)
- `lambda.tf` - Lambda function, IAM role/policies, Function URL, CloudWatch logs
- `monitoring.tf` - SNS topic + email subscription + EventBridge rule alerting on CloudFront API calls (via CloudTrail)
- `outputs.tf` - Output values for important resource attributes
- `lambda/view_counter.py` - Python Lambda function code
- `template.yaml` - CloudFormation **reference mirror** of the architecture (used for AWS Infrastructure Composer diagram). Terraform is the source of truth; this file can drift and is not deployed.
- `docs/iam-policies/` - Reference copies of the IAM policies attached to the `github-actions-cloud-resume` IAM user. **Not managed by Terraform** — source of truth is AWS; see its README for export commands.
- `.github/workflows/terraform.yml` - CI/CD (plan on PRs/branches, apply on `main` with `production` environment gate)

## Key Infrastructure Details

### S3 Backend State
- State stored in: `vitraiaws-terraform-states` bucket
- Key: `cloud-resume-challenge/terraform.tfstate`
- Region: `eu-west-1`
- Profile: `vitraigabor` (CI overrides with `-backend-config="profile="`)
- Encryption: Enabled
- State locking: DynamoDB table `terraform-state-locks`

### AWS Profile / Credentials
Local operations use the AWS profile `vitraigabor` (IAM Identity Center / SSO):
```bash
aws sso login --profile vitraigabor
eval $(aws configure export-credentials --profile vitraigabor --format env)
```

### Required Variables
Copy `terraform.tfvars.example` to `terraform.tfvars` (gitignored) and set:
- `alert_email` - email for CloudFront monitoring alerts (sensitive)
- `gallery_auth_credentials` - Base64 of `user:password` for gallery Basic Auth (sensitive): `echo -n "user:pass" | base64`

In CI these must be provided as `TF_VAR_*` environment variables from GitHub secrets.

### Lambda Function
- Runtime: Python 3.12, handler `lambda_function.lambda_handler`, timeout 10s
- Environment variables: `TABLE_NAME`, `RATE_LIMIT_TABLE_NAME`, `ALLOWED_ORIGINS` (comma-separated), `COUNTING_ORIGIN`
- Code location: `lambda/view_counter.py`, packaged by Terraform as `lambda_function.zip`
- Public Function URL (`authorization_type = "NONE"`) with CORS restricted to the apex and resume origins

When modifying Lambda code:
1. Edit `lambda/view_counter.py`
2. Run `terraform apply` - Terraform will automatically repackage and deploy
3. Check CloudWatch logs: `/aws/lambda/cloud-resume-view-counter`

### DynamoDB Tables
- `cloud-resume-view-counter`: partition key `id` (String); single item `id = "1"` with `views` (Number), atomically incremented. Initial item created by Terraform with `ignore_changes` so applies don't reset the count.
- `cloud-resume-visitor-rate-limits`: partition key `ip` (String), `ttl` attribute auto-expires records after 24h. Used for the 1-increment-per-hour-per-IP limit.
- Both on-demand billing (pay per request).

### CloudFront Distributions
- Origin Access Control (OAC) for S3 access on all three distributions (not legacy OAI)
- HTTPS only (HTTP redirects to HTTPS), TLS 1.2 minimum
- Price class 100 (EU + North America edge locations)
- Managed cache policy CachingOptimized (`658327ea-...`) and managed SecurityHeadersPolicy (`67f7725c-...`)
- Custom error responses map 403/404 → `/index.html` (SPA-style)
- Bucket policies allow `s3:GetObject` only to the `cloudfront.amazonaws.com` principal conditioned on the specific distribution ARN

### Gallery Basic Auth
`gallery-basic-auth.js` is rendered with `templatefile()`, embedding `var.gallery_auth_credentials` into the published CloudFront Function. The function runs on **every** viewer request (before cache), so all gallery objects including `manifest.json` require auth. Note: the credentials end up in plaintext in the published function code and in Terraform state — treat them as low-secrecy and never reuse this password elsewhere.

## CI/CD (GitHub Actions)

- Push to `main`/`develop`/`feature/**` and PRs run fmt/validate/plan; plan is uploaded as an artifact and commented on PRs
- Push to `main` triggers apply (gated by the `production` GitHub environment)
- AWS credentials come from repository secrets (`AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` for the `github-actions-cloud-resume` IAM user)
- `TF_VAR_alert_email` and `TF_VAR_gallery_auth_credentials` are supplied from secrets (secrets are never auto-exposed — each must be mapped in the workflow `env`, and the `TF_VAR_` name is case-sensitive/lowercase); any newly added required variable must also be wired in here or plans will fail

## Common Development Workflows

### Updating Website Content
Website content is **not** in this repo. Edit files in `cloud-resume-challenge-website` and push to its `main` branch — its GitHub Actions workflow syncs S3 and invalidates CloudFront. Manual invalidation if needed:
```bash
aws cloudfront create-invalidation --distribution-id <id> --paths "/*"
```

### Modifying Lambda Function
1. Edit `lambda/view_counter.py`
2. Run `terraform apply` (automatically rezips and deploys)
3. Test via Function URL or from website
4. Check logs: `aws logs tail /aws/lambda/cloud-resume-view-counter --follow`

### Rotating Gallery Credentials
1. Generate: `echo -n "user:newpass" | base64`
2. Update `gallery_auth_credentials` in `terraform.tfvars` (and the CI secret if wired there)
3. `terraform apply` — the CloudFront Function republishes (uses `create_before_destroy`)

### Adding New AWS Resources
1. Create or edit appropriate `.tf` file
2. Follow existing naming conventions (prefix with `cloud-resume-`, or site-specific prefix)
3. Add the appropriate site tag (`cloud-resume`/`ik-website`/`gallery` = `"true"`)
4. Use variables from `variables.tf` where applicable
5. Run `terraform plan` to review changes
6. Run `terraform apply` to create resources
7. If you change IAM policies for the GitHub Actions user in the Console, update the reference copies in `docs/iam-policies/`

### Troubleshooting

**CloudFront not showing updated content:**
- Check S3 bucket objects were uploaded
- Create CloudFront invalidation
- Verify CloudFront origin points to correct S3 bucket

**Lambda not responding:**
- Check CloudWatch logs: `/aws/lambda/cloud-resume-view-counter`
- Verify Function URL is public with correct CORS settings
- Check IAM role has DynamoDB permissions (both tables)
- Verify environment variables are set correctly

**View counter not incrementing:**
- Increments only happen from the `COUNTING_ORIGIN` (resume subdomain) and at most once per hour per IP
- The frontend also skips incrementing within the same browser session (`sessionStorage`)

**Certificate issues:**
- ACM certificate MUST be in `us-east-1` for CloudFront
- Check validation status in ACM console
- Ensure DNS validation records exist in Route53

**State lock errors:**
- Locking uses the `terraform-state-locks` DynamoDB table
- Force unlock: `terraform force-unlock <lock-id>`

**Gallery 401 loop:**
- Check the Basic Auth credentials match `gallery_auth_credentials` (Base64 of `user:pass`)
- The function compares the full `Authorization: Basic <b64>` header value

## Security Considerations

- All S3 buckets are **private** (no public access); CloudFront reaches them via OAC with distribution-ARN-scoped bucket policies
- Gallery is protected by HTTP Basic Auth at the CloudFront edge (viewer-request function, geo-restricted to HU/IT)
- Lambda Function URL is public but guarded by Origin/Referer validation and per-IP rate limiting (these headers are spoofable — the counter is best-effort, not a security boundary)
- Flood cost is bounded by the account-wide Lambda concurrency limit of 10 (no per-function reservation is possible at that limit — AWS requires ≥10 unreserved; if the account limit is raised, add `reserved_concurrent_executions`)
- All data encrypted at rest (S3, DynamoDB, Terraform state)
- TLS 1.2 minimum for CloudFront; managed security headers policy applied
- IAM: dedicated CI user with scoped policies (see `docs/iam-policies/`); Lambda role limited to the two DynamoDB tables + basic execution
- SNS email alerts fire on CloudFront distribution/OAC create/update/delete API calls
- Secrets (`terraform.tfvars`) are gitignored; `gallery_auth_credentials` is present in Terraform state and in the published CloudFront Function

## Cost Management

Expected monthly cost: ~$0.50
- Route53 Hosted Zone: $0.50/month (only significant cost)
- All other services within AWS Free Tier limits
- Domain registration: $8-13/year (one-time annual)

To avoid unexpected charges:
- Monitor CloudFront data transfer (Free Tier: 1TB/month)
- Monitor Lambda invocations (Free Tier: 1M requests/month)
- Keep CloudWatch log retention at 7 days
