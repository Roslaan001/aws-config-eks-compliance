# aws-config-eks

A multi-part Terraform series for enforcing **EKS compliance policies** using **AWS Config**, with automated alerting via **Amazon SNS** and **Amazon EventBridge**.

Each part is an independent, self-contained Terraform project targeting a specific compliance use case for Amazon Elastic Kubernetes Service (EKS) clusters.

---

## Series Overview

| Part | Folder | Compliance Rule | What it enforces |
|------|--------|-----------------|------------------|
| 01 | [`01-eks-supported-version`](./01-eks-supported-version/) | `EKS_CLUSTER_SUPPORTED_VERSION` | EKS cluster runs Kubernetes `>= 1.32` |
| 02 | [`02-eks-control-plane-logging`](./02-eks-control-plane-logging/) | `EKS_CLUSTER_LOG_ENABLED` | All 5 control plane log types are enabled (with auto-remediation) |
| 03 | [`03-eks-endpoint-access`](./03-eks-endpoint-access/) | `EKS_ENDPOINT_NO_PUBLIC_ACCESS` | EKS cluster API endpoint public access is disabled/restricted (with optional auto-remediation) |
| 04 | [`04-eks-secrets-encryption`](./04-eks-secrets-encryption/) | `EKS_SECRETS_ENCRYPTED` | Kubernetes secrets are encrypted at rest using AWS KMS |
| 05 | [`05-eks-iam-access`](./05-eks-iam-access/) | `IAM_POLICY_NO_STATEMENTS_WITH_ADMIN_ACCESS` | Customer managed policies do not grant wildcard admin access |

---

## How It Works

Each project uses the same core pattern:

```
EKS Cluster change detected
        ↓
AWS Config evaluates the rule
        ↓
Compliance state changes (COMPLIANT ↔ NON_COMPLIANT)
        ↓
Amazon EventBridge fires (filtered — compliance changes only)
        ↓
Custom SNS Topic
        ↓
📧 Email alert  +  💬 Slack (optional)
```

The EventBridge filter ensures only meaningful compliance transitions reach your inbox — not noisy S3 delivery logs or periodic snapshot notifications.

---

## Prerequisites

| Tool | Minimum Version |
|---|---|
| [Terraform](https://developer.hashicorp.com/terraform/downloads) | `>= 1.3` |
| [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/) | `>= 2.0` |
| AWS credentials configured | `eu-west-2` (London) |

Your AWS IAM user/role requires permissions for: EKS, Config, SNS, EventBridge, IAM, and S3.

---

## Shared Concepts

### Notification Alerting
Every project includes a `notifications.tf` file that provisions:
- A **custom SNS topic** for compliance alerts
- An **EventBridge rule** filtering `Config Rules Compliance Change` events
- An **email subscription** to the SNS topic
- An optional **AWS Chatbot Slack integration** (enabled by default; requires one-time manual console authorization — see each project's README for setup)

### Variables
Each project accepts the same core variables via `terraform.tfvars`:

```hcl
alert_email      = "your-email@example.com"
slack_team_id    = "T0123456789"   # Optional — Slack Workspace ID
slack_channel_id = "C0123456789"   # Optional — Slack Channel ID
```

> `terraform.tfvars` is in `.gitignore` — never commit credentials to source control.

---

## Deploying a Project

Each project is deployed independently from its own folder:

```bash
cd <project-folder>
terraform init
terraform plan
terraform apply
```

See the README inside each folder for project-specific details, especially for any one-time setup such as Slack authorization or IAM prerequisites.

---

## Repository Structure

```
aws-config-eks/
├── README.md                            ← You are here
├── .gitignore
├── context.md
│
├── 01-eks-supported-version/
│   ├── README.md
│   ├── main.tf
│   ├── eks.tf
│   ├── s3-bucket.tf
│   ├── variables.tf
│   ├── notifications.tf
│   ├── output.tf
│   └── terraform.tfvars                 ← Local/Secrets (Gitignored)
│
├── 02-eks-control-plane-logging/
│   ├── README.md
│   ├── main.tf
│   ├── eks.tf
│   ├── s3-bucket.tf
│   ├── variables.tf
│   ├── notifications.tf
│   ├── auto-rem.tf
│   ├── output.tf
│   └── terraform.tfvars
│
├── 03-eks-endpoint-access/
│   ├── README.md
│   ├── main.tf
│   ├── eks.tf
│   ├── s3-bucket.tf
│   ├── variables.tf
│   ├── notifications.tf
│   ├── auto-rem.tf                      ← Optional auto-remediation
│   ├── output.tf
│   └── terraform.tfvars
│
├── 04-eks-secrets-encryption/
│   ├── README.md
│   ├── main.tf
│   ├── eks.tf
│   ├── s3-bucket.tf
│   ├── variables.tf
│   ├── notifications.tf
│   ├── output.tf
│   └── terraform.tfvars
│
└── 05-eks-iam-access/
    ├── README.md
    ├── main.tf
    ├── iam-violation.tf
    ├── s3-bucket.tf
    ├── variables.tf
    ├── notifications.tf
    ├── output.tf
    └── terraform.tfvars
```

---

## License

MIT
