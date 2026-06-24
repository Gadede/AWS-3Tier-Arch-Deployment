# Production-Style 3-Tier AWS Architecture with Terraform & CI/CD

A fully automated, production-style three-tier web architecture on AWS, provisioned with modular Terraform and deployed through a secure GitHub Actions CI/CD pipeline. The project includes keyless OIDC authentication, secret and IaC scanning, gated deploy/destroy workflows, and an automated zero-downtime patching pipeline built on golden AMIs and rolling instance refresh.

---

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Key Features](#key-features)
- [Repository Structure](#repository-structure)
- [Prerequisites](#prerequisites)
- [Bootstrap (One-Time Setup)](#bootstrap-one-time-setup)
- [Deployment](#deployment)
- [CI/CD Pipeline](#cicd-pipeline)
- [Automated Patching (Golden AMI + Instance Refresh)](#automated-patching-golden-ami--instance-refresh)
- [Teardown](#teardown)
- [Security Design](#security-design)
- [Lessons Learned](#lessons-learned)
- [Future Improvements](#future-improvements)

---

## Architecture Overview

The infrastructure follows the classic three-tier pattern, with each tier isolated in its own subnet group across two Availability Zones for high availability.

```
                            Internet
                               │
                    ┌──────────▼───────────┐
                    │   Public ALB (HTTP)  │   internet-facing
                    └──────────┬───────────┘
                               │
          ┌────────────────────▼────────────────────┐
          │   Web Tier — Auto Scaling Group          │   public subnets (2 AZs)
          │   (nginx, golden AMI)                    │
          └────────────────────┬────────────────────┘
                               │
                    ┌──────────▼───────────┐
                    │  Internal ALB (HTTP) │   internal only
                    └──────────┬───────────┘
                               │
          ┌────────────────────▼────────────────────┐
          │   App Tier — Auto Scaling Group          │   private subnets (2 AZs)
          │   (Python service, golden AMI)           │
          └────────────────────┬────────────────────┘
                               │
          ┌────────────────────▼────────────────────┐
          │   Database Tier — Amazon RDS (MySQL)     │   isolated DB subnets (2 AZs)
          │   encrypted, Multi-AZ-capable            │
          └─────────────────────────────────────────┘
```

**Network flow:** Internet traffic reaches the public ALB, which forwards to the web tier. The web tier reaches the app tier through an internal ALB. The app tier connects to RDS. Each tier's security group permits traffic only from the tier directly above it, enforcing least-privilege network access.

**Outbound access:** Private subnets reach the internet for package installs and AWS API calls through NAT gateways (one per AZ), while remaining unreachable from the internet.

---

## Key Features

### Infrastructure
- **Multi-AZ VPC** with public (web), private (app), and isolated (database) subnets across two Availability Zones
- **Web and app tiers** on Auto Scaling Groups behind public and internal Application Load Balancers
- **Encrypted Amazon RDS (MySQL)** with the master password managed in AWS Secrets Manager — no credentials in code or state
- **Tiered security groups** where each tier accepts traffic only from the adjacent upstream tier
- **NAT gateways** for controlled outbound access from private subnets
- **Fully modular Terraform** (network, security groups, compute, ALB, database, image-builder) with clean input/output contracts
- **Remote state** in S3 with native state locking

### CI/CD
- **Keyless authentication** via GitHub OIDC — no long-lived AWS credentials stored anywhere
- **Validation pipeline**: `fmt` → `validate` → `tflint` → `plan` on every push
- **Secret scanning** with Gitleaks as a gating job
- **IaC security scanning** with tfsec, Checkov, and Trivy
- **Manual approval gate** before any apply
- **Concurrency control** to prevent state-lock races
- **Gated destroy workflow** with manual trigger, typed confirmation, and reviewer approval

### Operations (Day 2)
- **Automated patching** via EC2 Image Builder golden AMIs
- **Zero-downtime rollout** through Auto Scaling Group rolling instance refresh
- **Least-privilege IAM** scoped to the actual create *and* destroy lifecycle

---

## Repository Structure

```
.
├── main.tf                     # Root module — wires all child modules together
├── variables.tf                # Root input variables
├── outputs.tf                  # Root outputs
├── provider.tf                 # AWS provider configuration
├── backend.tf                  # S3 remote state backend
├── data.tf                     # Shared data sources (e.g. Ubuntu AMI lookup)
├── .gitignore                  # Excludes state, .terraform/, secrets
│
├── modules/
│   ├── network/                # VPC, subnets, IGW, NAT, route tables, DB subnet group
│   ├── security_group/         # All tier security groups (web, app, db, ALBs)
│   ├── alb/                    # Public + internal ALBs, target groups, listeners
│   ├── compute/                # Launch templates, ASGs, scaling policies, user_data
│   ├── database/               # RDS instance (subnet group + SG passed in)
│   └── image-builder/          # EC2 Image Builder golden AMI pipeline
│
└── .github/workflows/
    ├── deploy.yml              # Validate, scan, plan, approve, apply
    ├── terraform-destroy.yml   # Gated teardown
    ├── bake-ami.yml            # Trigger golden AMI build
    └── instance-refresh.yml    # Roll ASGs onto the latest golden AMI
```

### Module Contract Pattern

Each module is self-contained: it owns only its own resources and exposes them through declared outputs. The **root module** is the wiring harness — it reads outputs from one module and passes them as inputs to another. No child module reaches directly into another; all cross-module values flow through the root.

For example, the network module outputs `vpc_id`, `public_subnet_ids`, `private_subnet_ids`, and `db_subnet_group_name`; the root passes those into the ALB, compute, and database modules as inputs.

---

## Prerequisites

- **Terraform** >= 1.13
- **AWS account** with permissions to create the bootstrap resources
- **AWS CLI** configured (`aws configure`) with credentials for the target account
- **A GitHub repository** with Actions enabled
- **Git Bash** or any POSIX shell (the project was developed on Windows with Git Bash / MINGW64)

---

## Bootstrap (One-Time Setup)

These resources live *outside* Terraform and must exist before the first deploy. They are intentionally not managed by the stack that uses them (to avoid a chicken-and-egg dependency on the state backend).

### 1. Create the S3 state bucket

```bash
aws s3 mb s3://<your-state-bucket-name> --region us-east-2
```

Update `backend.tf` with the bucket name. The bucket name must match **exactly** in three places: `backend.tf`, the IAM policy's S3 ARNs, and the real bucket.

### 2. Create the GitHub OIDC identity provider

In IAM → Identity providers, add a provider for `token.actions.githubusercontent.com` (audience `sts.amazonaws.com`).

### 3. Create the deployment IAM role

Create a role with a trust policy pinned to your repository and branch:

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {
      "Federated": "arn:aws:iam::<ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com"
    },
    "Action": "sts:AssumeRoleWithWebIdentity",
    "Condition": {
      "StringEquals": {
        "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
      },
      "StringLike": {
        "token.actions.githubusercontent.com:sub": "repo:<USERNAME>/<REPO>:ref:refs/heads/main"
      }
    }
  }]
}
```

Attach the least-privilege permissions policy (see [Security Design](#security-design)).

### 4. Create the Image Builder service-linked role

```bash
aws iam create-service-linked-role --aws-service-name imagebuilder.amazonaws.com
```

### 5. Configure GitHub secrets

In the repo: Settings → Secrets and variables → Actions:
- `AWS_OIDC_ROLE_ARN` → `arn:aws:iam::<ACCOUNT_ID>:role/<role-name>`

### 6. Create the protected environment

Settings → Environments → create `production` with **Required reviewers** enabled. This is what gates the apply and destroy workflows.

---

## Deployment

The stack uses a **two-phase bootstrap** for the compute AMI, because the golden AMI does not exist on a first deploy.

### Phase 1 — Deploy on the base Ubuntu AMI

In `modules/compute/main.tf`, ensure the launch templates use the base AMI:

```hcl
image_id = var.ami_id   # data.aws_ami.ubuntu.id
```

Then deploy:

```bash
terraform init
terraform plan
terraform apply
```

Or push to `main` and let the pipeline run (recommended).

### Phase 2 — Switch to the golden AMI

After the stack is up, [bake a golden AMI](#automated-patching-golden-ami--instance-refresh), then switch the launch templates:

```hcl
image_id = data.aws_ami.golden.id
```

Apply again — the launch template change triggers a rolling instance refresh onto the patched image.

> **Note on capacity:** Start with `min_size = 1` / `desired_capacity = 1` on both ASGs. With `t3.micro` instances, four running instances consume the full default 8-vCPU account quota, leaving no room for the Image Builder build instance. Keeping the floor at 1 avoids hitting the quota.

---

## CI/CD Pipeline

The deploy pipeline (`deploy.yml`) runs as a gated sequence of jobs:

```
gitleaks (secret scan)
   │
   ├──> formatting-validate-linting  (fmt, validate, tflint, plan)
   │
   └──> security-scan                (tfsec, Checkov, Trivy)
              │
              ▼
      plan-manual-approval           (issue-based reviewer approval)
              │
              ▼
      deploy-infrastructure          (terraform apply)
```

- **Gitleaks** runs first and gates everything — if a secret is found, nothing proceeds.
- **Validation and security scans** run in parallel after the secret scan passes.
- **Manual approval** pauses the pipeline until a reviewer approves, with the Terraform plan attached for review.
- **Apply** runs only after approval.

Authentication is fully keyless: each job assumes the deployment role via GitHub OIDC and receives short-lived STS credentials. No AWS keys are ever stored in the repo.

A `concurrency` block ensures only one pipeline run per branch touches the shared state at a time, preventing state-lock collisions.

---

## Automated Patching (Golden AMI + Instance Refresh)

Patching follows the **immutable infrastructure** model: servers are never patched in place. Instead, a new pre-patched image is baked and instances are rolled onto it.

### How it works

1. **Bake** — An EC2 Image Builder pipeline takes the base Ubuntu image, applies all OS updates, installs the baseline software, and runs a validation phase that aborts the build if anything is broken. The output is a versioned, tagged golden AMI. It runs on a schedule and can be triggered on demand.

2. **Roll** — The launch templates reference the latest golden AMI via a Terraform data source (`data.aws_ami.golden`, filtered by tag). When the AMI changes, the Auto Scaling Group performs a **rolling instance refresh**: new instances launch from the golden AMI, must pass the ALB health check before receiving traffic, and only then do the old instances drain (via deregistration delay) and terminate — a batch at a time.

3. **Result** — Zero downtime. The ALB only routes to healthy targets, and connection draining lets in-flight requests finish before any instance is removed.

### Why it's safe

The compute tier is **stateless** — all persistent data lives in RDS. This is the core reason for the three-tier separation: the compute layer is fully disposable and can be replaced at will without data loss.

### Triggering a patch cycle

```bash
# Bake a new golden AMI (or use the bake-ami.yml workflow):
aws imagebuilder start-image-pipeline-execution \
  --image-pipeline-arn $(aws imagebuilder list-image-pipelines \
    --query "imagePipelineList[?name=='<project>-golden-ami-pipeline'].arn" \
    --output text)

# After the bake completes, roll the fleet (or use instance-refresh.yml):
aws autoscaling start-instance-refresh \
  --auto-scaling-group-name <project>-web-asg \
  --preferences '{"MinHealthyPercentage":50,"InstanceWarmup":600}'
```

### Verifying the roll

```bash
# Confirm running instances are on the golden AMI:
aws ec2 describe-instances \
  --filters "Name=tag:Tier,Values=web,app" "Name=instance-state-name,Values=running" \
  --query "Reservations[].Instances[].{Tier:Tags[?Key=='Tier']|[0].Value,AMI:ImageId}" \
  --output table

# Confirm targets are healthy:
aws elbv2 describe-target-health --target-group-arn <tg-arn> \
  --query "TargetHealthDescriptions[].TargetHealth.State" --output text
```

> **Tier-specific note:** The golden AMI ships nginx (for the web tier). The app tier runs a Python service on the same port, so its `user_data` stops nginx at boot before starting the app — otherwise the baked-in nginx answers the health check with a 404. A cleaner long-term approach is a separate golden AMI per tier.

---

## Teardown

Infrastructure can be destroyed two ways.

### Local

```bash
terraform destroy
```

### Via the gated destroy workflow

Trigger `terraform-destroy.yml` from the Actions tab. It requires:
1. A **manual trigger** (`workflow_dispatch`) — never runs on a push
2. A **typed confirmation** (you must type `destroy`)
3. **Reviewer approval** via the protected `production` environment

> The deployment role needs delete-side permissions (e.g. `ec2:DisassociateAddress`, `iam:DetachRolePolicy`, `imagebuilder:DeleteImagePipeline`, `kms:RetireGrant`). These are included in the least-privilege policy. The S3 state bucket and the Secrets Manager recovery window persist after destroy by design.

---

## Security Design

Security is built in at every layer rather than bolted on:

- **Keyless authentication** — GitHub OIDC federation; no long-lived AWS keys anywhere.
- **Least-privilege IAM** — the deployment role is scoped to the specific actions the stack uses, for both create and destroy. Where AWS supports resource-level scoping (S3 state bucket, Image Builder roles), permissions are pinned to exact ARNs; `iam:PassRole` is conditioned to specific services.
- **Encryption** — RDS storage is encrypted; the master password is generated and stored in Secrets Manager, never in code or state.
- **Network segmentation** — three isolated subnet tiers; each security group accepts traffic only from the adjacent upstream tier; the database tier has no internet path.
- **Secret scanning** — Gitleaks gates the pipeline against committed credentials.
- **IaC scanning** — tfsec, Checkov, and Trivy check for misconfigurations before apply.
- **Gated operations** — both deploy and destroy require human approval through a protected environment.
- **State protection** — remote state in S3 is encrypted, access-scoped, and protected by native locking.

---

## Lessons Learned

A selection of the real problems solved while building this end to end:

- **Module contracts** — cross-module references only resolve when both ends are declared: an `output` in the source module and a matching `variable` in the consumer. The three error shapes (`Unsupported argument`, `Missing required argument`, `Unsupported attribute`) each point to a specific side of that contract.
- **ASG vs. scaling policy conflict** — an Auto Scaling Group timed out because the CPU scaling policy was scaling instances *down* (idle CPU on a fresh fleet) while Terraform waited for them to be up. Aligning `min_size` with `desired_capacity` and setting `wait_for_capacity_timeout = "0"` resolved it.
- **"Successful apply, zero instances"** — a launch template pointing at a missing AMI fails the *launch* after the ASG is created; with `wait_for_capacity_timeout = "0"`, Terraform reports success anyway. Always verify what is actually running, not just the apply status.
- **Health-check 404** — a shared golden AMI's baked-in nginx hijacked the app tier's `/health` check. Diagnosed via the target group health reason; fixed in `user_data`.
- **IAM one action at a time** — KMS, Secrets Manager, and Image Builder permissions surfaced incrementally as each service was first used. Destroy revealed additional delete-only actions (e.g. `DisassociateAddress`, `DetachRolePolicy`) that the create path never exercised — a reminder that least-privilege policies must cover the full lifecycle.
- **CI/CD runs what's pushed** — the pipeline always runs the remote `main`, never local edits. `git show origin/main:<file>` confirms what will actually deploy.

---

## Future Improvements

- **Separate golden AMIs per tier** — a web AMI with nginx and an app AMI with Python, eliminating the boot-time nginx workaround.
- **IAM Access Analyzer** — generate the deployment policy from observed CloudTrail activity after a full create + destroy cycle, for a verified-minimal policy.
- **Amazon Inspector** — continuous CVE detection to trigger bakes automatically.
- **SSM Patch Manager** — as a backstop for emergency in-place patches between bakes.
- **Multi-environment** — split into `dev`/`staging`/`prod` via separate state keys or workspaces.
- **HTTPS / TLS** — add ACM certificates and HTTPS listeners on the public ALB.
- **Database migrations** — a deliberate, backward-compatible migration step for schema changes during rolling deploys.

---

## License

This is a personal learning / portfolio project. Use the code as a reference freely.
