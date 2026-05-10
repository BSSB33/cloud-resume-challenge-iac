# IAM Policies - Reference Copies

These are reference copies of the IAM policies attached to the `github-actions-cloud-resume` user.
They are **not managed by Terraform** — the source of truth is AWS.

Update these files whenever you change a policy in the Console.

## Policies

| File | Policy Name | Purpose |
|------|-------------|---------|
| `GitHubActions-Terraform-Application.json` | GitHubActions-Terraform-Application | Terraform app-level resources |
| `GitHubActions-Terraform-Infrastructure.json` | GitHubActions-Terraform-Infrastructure | Terraform infrastructure resources |
| `GitHubActions-CloudResume-S3-Policy.json` | GitHubActions-CloudResume-S3-Policy | S3 sync for website deployment |
| `GitHubActions-CloudResume-CloudFront-Policy.json` | GitHubActions-CloudResume-CloudFront-Policy | CloudFront invalidation + function management |
| `GitHubActions-Terraform-State.json` | GitHubActions-Terraform-State | Terraform S3 state backend access |

## Exporting current state from AWS

```bash
# Run each of these and commit the output to keep copies in sync
aws iam get-policy-version \
  --policy-arn arn:aws:iam::971725886961:policy/GitHubActions-Terraform-Application \
  --version-id $(aws iam get-policy --policy-arn arn:aws:iam::971725886961:policy/GitHubActions-Terraform-Application --profile vitraigabor --query 'Policy.DefaultVersionId' --output text) \
  --profile vitraigabor --query 'PolicyVersion.Document' --output json \
  > docs/iam-policies/GitHubActions-Terraform-Application.json

aws iam get-policy-version \
  --policy-arn arn:aws:iam::971725886961:policy/GitHubActions-Terraform-Infrastructure \
  --version-id $(aws iam get-policy --policy-arn arn:aws:iam::971725886961:policy/GitHubActions-Terraform-Infrastructure --profile vitraigabor --query 'Policy.DefaultVersionId' --output text) \
  --profile vitraigabor --query 'PolicyVersion.Document' --output json \
  > docs/iam-policies/GitHubActions-Terraform-Infrastructure.json

aws iam get-policy-version \
  --policy-arn arn:aws:iam::971725886961:policy/GitHubActions-CloudResume-S3-Policy \
  --version-id $(aws iam get-policy --policy-arn arn:aws:iam::971725886961:policy/GitHubActions-CloudResume-S3-Policy --profile vitraigabor --query 'Policy.DefaultVersionId' --output text) \
  --profile vitraigabor --query 'PolicyVersion.Document' --output json \
  > docs/iam-policies/GitHubActions-CloudResume-S3-Policy.json

aws iam get-policy-version \
  --policy-arn arn:aws:iam::971725886961:policy/GitHubActions-CloudResume-CloudFront-Policy \
  --version-id $(aws iam get-policy --policy-arn arn:aws:iam::971725886961:policy/GitHubActions-CloudResume-CloudFront-Policy --profile vitraigabor --query 'Policy.DefaultVersionId' --output text) \
  --profile vitraigabor --query 'PolicyVersion.Document' --output json \
  > docs/iam-policies/GitHubActions-CloudResume-CloudFront-Policy.json

aws iam get-policy-version \
  --policy-arn arn:aws:iam::971725886961:policy/GitHubActions-Terraform-State \
  --version-id $(aws iam get-policy --policy-arn arn:aws:iam::971725886961:policy/GitHubActions-Terraform-State --profile vitraigabor --query 'Policy.DefaultVersionId' --output text) \
  --profile vitraigabor --query 'PolicyVersion.Document' --output json \
  > docs/iam-policies/GitHubActions-Terraform-State.json
```
