# Part 03 — EKS Endpoint Access Monitoring

> Part of the [aws-config-eks](../README.md) series — enforcing EKS compliance with AWS Config.

This project enforces that every Amazon EKS cluster in your AWS account has its public endpoint access restricted or disabled, helping you comply with AWS security best practices and prevent unauthorized access to your Kubernetes API server.

---

## Table of Contents

- [What This Enforces](#what-this-enforces)
- [Architecture](#architecture)
- [Auto-Remediation](#auto-remediation)
- [Resources Created](#resources-created)
- [Prerequisites](#prerequisites)
- [Slack Authorization Setup](#slack-authorization-setup)
- [Variables](#variables)
- [Usage](#usage)
- [Outputs](#outputs)
- [Checking Compliance](#checking-compliance)
- [Troubleshooting](#troubleshooting)

---

## What This Enforces

| AWS Config Rule | `EKS_ENDPOINT_NO_PUBLIC_ACCESS` |
|---|---|
| **COMPLIANT** | Public endpoint access is disabled (only private endpoint is enabled) |
| **NON_COMPLIANT** | Public endpoint access is enabled |
| **Evaluation trigger** | On configuration change + periodic |

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                     AWS Account (eu-west-2)             │
│                                                         │
│  ┌──────────────────┐  evaluates  ┌──────────────────┐ │
│  │   EKS Cluster    │ ──────────► │  AWS Config Rule │ │
│  │  my-cluster      │             │  eks-endpoint-   │ │
│  │  (public endpoint)             │  no-public-access│ │
│  └──────────────────┘             └────────┬─────────┘ │
│                                            │            │
│                                   state changes only    │
│                                            │            │
│                                            ▼            │
│                                   ┌──────────────────┐ │
│                                   │  Amazon          │ │
│                                   │  EventBridge     │ │
│                                   │  Rule            │ │
│                                   └────────┬─────────┘ │
│                                            │            │
│                                            ▼            │
│                                   ┌──────────────────┐ │
│                                   │  SNS Topic       │ │
│                                   │  (compliance     │ │
│                                   │   alerts only)   │ │
│                                   └────────┬─────────┘ │
│                                            │            │
│                           ┌────────────────┤            │
│                           ▼                ▼            │
│                  ┌──────────────┐ ┌──────────────────┐ │
│                  │ 📧 Email     │ │ 💬 Slack Chatbot │ │
│                  │ Subscription │ │   (optional)     │ │
│                  └──────────────┘ └──────────────────┘ │
│                                                         │
│  Config history ──────────────────────► S3 Bucket      │
└─────────────────────────────────────────────────────────┘
```

---

## Auto-Remediation (Optional)

To prevent accidental modifications to your EKS clusters, automated remediation for public endpoint access is **disabled by default** (commented out in [auto-rem.tf](auto-rem.tf)). 

If enabled, when a cluster is evaluated as `NON_COMPLIANT`, AWS Config automatically triggers remediation:

1. The `aws_config_remediation_configuration` invokes a custom SSM Automation document (`Remediate-DisableEksPublicEndpoint`).
2. Systems Manager assumes the `eks-endpoint-remediation-role` IAM role and calls the EKS `UpdateClusterConfig` API to disable the public endpoint (`endpointPublicAccess = false`) and enable the private endpoint (`endpointPrivateAccess = true`).
3. AWS Config re-evaluates the cluster → status transitions to `COMPLIANT`.
4. EventBridge detects the compliance state change and publishes a notification via SNS.

To enable this:
1. Uncomment the entire block of code in [auto-rem.tf](auto-rem.tf).
2. Run `terraform apply`.

---

## Resources Created

| File | Resource | Description |
|---|---|---|
| `eks.tf` | `module.eks` | EKS cluster (`my-cluster`, Kubernetes `1.35`) with public access enabled for testing |
| `main.tf` | `module.aws-config` | AWS Config recorder, delivery channel, and the `EKS_ENDPOINT_NO_PUBLIC_ACCESS` rule |
| `s3-bucket.tf` | `aws_s3_bucket.config` | S3 bucket for AWS Config configuration history snapshots |
| `s3-bucket.tf` | `aws_s3_bucket_policy.config` | Bucket policy granting AWS Config write access |
| `variables.tf` | — | Declares input variables for the email and Slack configuration |
| `notifications.tf` | `aws_sns_topic.compliance_alerts` | Custom SNS topic: `eks-endpoint-access-compliance-alerts` |
| `notifications.tf` | `aws_sns_topic_policy.compliance` | Allows EventBridge to publish to the SNS topic |
| `notifications.tf` | `aws_cloudwatch_event_rule.compliance` | EventBridge rule matching `Config Rules Compliance Change` |
| `notifications.tf` | `aws_cloudwatch_event_target.sns` | Routes EventBridge events to the SNS topic |
| `notifications.tf` | `aws_sns_topic_subscription.email` | Email subscription to the SNS topic |
| `notifications.tf` | `aws_iam_role.chatbot` | IAM role assumed by AWS Chatbot |
| `notifications.tf` | `aws_chatbot_slack_channel_configuration.slack` | AWS Chatbot configuration mapping the Slack workspace and channel |
| `auto-rem.tf` | `aws_ssm_document.eks_endpoint_remediation` | Custom SSM Automation document that calls EKS `UpdateClusterConfig` (Optional, commented out) |
| `auto-rem.tf` | `aws_iam_role.remediation_role` | IAM role assumed by Systems Manager to modify EKS clusters (Optional, commented out) |
| `auto-rem.tf` | `aws_iam_role_policy.eks_remediation_policy` | Inline policy granting `eks:UpdateClusterConfig` permission (Optional, commented out) |
| `auto-rem.tf` | `aws_config_remediation_configuration.eks_endpoint_auto_fix` | Binds the AWS Config rule to the SSM remediation document (Optional, commented out) |
| `terraform.tfvars` | — | Local variables file (ignored by Git) |

---

## Prerequisites

- Terraform `>= 1.3`
- AWS CLI `>= 2.0`
- AWS credentials configured for region `eu-west-2`

---

## Slack Authorization Setup

AWS Chatbot Slack configurations require a one-time manual OAuth flow in the AWS Console before Terraform can deploy or manage them. If this is not completed first, `terraform apply` will fail.

1. Open **AWS Chatbot** in the AWS Console.
2. Under **Configured clients**, select **Slack** and click **Configure client**.
3. Complete the Slack OAuth authorization flow to grant AWS Chatbot access to your workspace.
4. Note down your **Workspace/Team ID** (starts with `T`) and target **Channel ID** (starts with `C` or `G`).
   <details>
   <summary> How to find your Workspace ID & Channel ID</summary>

   * **Workspace ID (`slack_team_id`):**
     * **In Slack (Web):** Open Slack in a browser, and look at the URL: `https://app.slack.com/client/TXXXXXXXXXX/CXXXXXXXXXX`. The ID starting with `T` is your Workspace ID.
     * **In Slack (Desktop):** Click your workspace name in the top-left, select **Workspace settings** (opens in a browser), and check the URL for the `T...` ID.
     * **In AWS Console:** After completing the Workspace authorization flow in AWS Chatbot, your Workspace ID is displayed in the Configured Clients list.
   * **Channel ID (`slack_channel_id`):**
     * **In Slack (Desktop/Web):** Right-click the channel name in the left sidebar, click **Copy Link**, and paste it into a text editor. The URL ends with the channel ID: `https://.../archives/CXXXXXXXXXX`.
     * **Alternatively:** Click the channel name at the top of the chat, go to the **About** tab in the modal, and scroll to the bottom to find the **Channel ID**.
   </details>

---

## Variables

Create a `terraform.tfvars` file to store your credentials:

```hcl
alert_email      = "your-team@example.com"
slack_team_id    = "T0123456789"
slack_channel_id = "C0123456789"
```

---

## Usage

```bash
# 1. Initialize Terraform
terraform init

# 2. Preview what will be created
terraform plan

# 3. Deploy all resources
terraform apply

# 4. (When done) Destroy all resources
terraform destroy
```

---

## Outputs

| Output | Description |
|---|---|
| `config_recorder_id` | The ID of the AWS Config configuration recorder |
| `config_s3_bucket_name` | The name of the S3 bucket created for AWS Config history |
| `sns_topic_arn` | The ARN of the custom SNS topic for compliance alerts |
| `sns_subscription_arn` | The ARN of the email subscription |
| `eks_cluster_name` | The name of the EKS cluster |
| `eks_cluster_arn` | The ARN of the EKS cluster |
| `chatbot_slack_arn` | The ARN of the AWS Chatbot Slack channel configuration |

---

## Checking Compliance

### Trigger an immediate re-evaluation

```bash
aws configservice start-config-rules-evaluation \
  --config-rule-names eks-endpoint-no-public-access \
  --region eu-west-2
```

### View current compliance status

```bash
aws configservice get-compliance-details-by-config-rule \
  --config-rule-name eks-endpoint-no-public-access \
  --region eu-west-2
```

**Expected output** (due to `endpoint_public_access = true` in `eks.tf`):

```json
{
  "EvaluationResults": [
    {
      "ComplianceType": "NON_COMPLIANT",
      "EvaluationResultIdentifier": {
        "EvaluationResultQualifier": {
          "ConfigRuleName": "eks-endpoint-no-public-access",
          "ResourceType": "AWS::EKS::Cluster",
          "ResourceId": "my-cluster"
        }
      }
    }
  ]
}
```

### Check remediation execution status (if enabled)

```bash
aws configservice describe-remediation-execution-status \
  --config-rule-name eks-endpoint-no-public-access \
  --region eu-west-2
```

### Verify your SNS subscription is confirmed

```bash
aws sns list-subscriptions-by-topic \
  --topic-arn $(aws sns list-topics --region eu-west-2 \
    --query "Topics[?contains(TopicArn,'endpoint-access')].TopicArn" \
    --output text) \
  --region eu-west-2 \
  --output table
```

---

## Troubleshooting

### No alert email received

1. Verify email subscription confirmation has been clicked (sender is `no-reply@sns.amazonaws.com`).
2. EventBridge rule only triggers on a compliance state transition (e.g. `INSUFFICIENT_DATA` $\rightarrow$ `NON_COMPLIANT`). If it was already non-compliant, you will not receive a second email.

### `InvalidRequestException: Slack workspace not authorized`

AWS Chatbot Slack configurations require a one-time manual OAuth flow in the AWS Console before Terraform can manage them. See [Slack Authorization Setup](#slack-authorization-setup) above.

### Remediation not executing (if enabled)

1. Verify the SSM document exists: `aws ssm describe-document --name Remediate-DisableEksPublicEndpoint --region eu-west-2`
2. Check SSM Automation execution history: `aws ssm describe-automation-executions --filter "Key=DocumentNamePrefix,Values=Remediate-DisableEksPublicEndpoint" --region eu-west-2`
3. Confirm the IAM role `eks-endpoint-remediation-role` has `eks:UpdateClusterConfig` permission
