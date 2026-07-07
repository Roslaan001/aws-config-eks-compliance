# Part 04 — EKS Secrets Encryption Monitoring

> Part of the [aws-config-eks](../README.md) series — enforcing EKS compliance with AWS Config.

This project enforces that every Amazon EKS cluster in your AWS account encrypts Kubernetes secrets at rest using AWS KMS (Key Management Service). This secures sensitive application configuration data stored in `etcd`.

---

## Table of Contents

- [What This Enforces](#what-this-enforces)
- [Architecture](#architecture)
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

| AWS Config Rule | `EKS_SECRETS_ENCRYPTED` |
|---|---|
| **COMPLIANT** | EKS cluster is configured with `encryptionConfig` referencing a KMS Key ARN for the `secrets` resource |
| **NON_COMPLIANT** | EKS cluster does not have secrets encryption enabled |
| **Evaluation trigger** | On configuration change + periodic |

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                     AWS Account (eu-west-2)             │
│                                                         │
│  ┌──────────────────┐  evaluates  ┌──────────────────┐ │
│  │   EKS Cluster    │ ──────────► │  AWS Config Rule │ │
│  │  my-cluster      │             │  eks-secrets-    │ │
│  │  (unencrypted)   │             │  encrypted       │ │
│  └────────┬─────────┘             └────────┬─────────┘ │
│    (Encryption Config)            state changes only    │
│           │                                │            │
│           ▼                                ▼            │
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

## Resources Created

| File | Resource | Description |
|---|---|---|
| `eks.tf` | `module.eks` | EKS cluster (`my-cluster`, Kubernetes `1.35`) with secrets encryption initially disabled for testing |
| `main.tf` | `module.aws-config` | AWS Config recorder, delivery channel, and the `EKS_SECRETS_ENCRYPTED` rule |
| `s3-bucket.tf` | `aws_s3_bucket.config` | S3 bucket for AWS Config configuration history snapshots |
| `s3-bucket.tf` | `aws_s3_bucket_public_access_block.config` | Blocks public access to the AWS Config history bucket |
| `s3-bucket.tf` | `aws_s3_bucket_policy.config` | Bucket policy granting AWS Config write access |
| `variables.tf` | — | Declares input variables for the email and Slack configuration |
| `notifications.tf` | `aws_sns_topic.compliance_alerts` | Custom SNS topic: `eks-secrets-encryption-compliance-alerts` |
| `notifications.tf` | `aws_sns_topic_policy.compliance` | Allows EventBridge to publish to the SNS topic |
| `notifications.tf` | `aws_cloudwatch_event_rule.compliance` | EventBridge rule matching `Config Rules Compliance Change` |
| `notifications.tf` | `aws_cloudwatch_event_target.sns` | Routes EventBridge events to the SNS topic |
| `notifications.tf` | `aws_sns_topic_subscription.email` | Email subscription to the SNS topic |
| `notifications.tf` | `aws_iam_role.chatbot` | IAM role assumed by AWS Chatbot |
| `notifications.tf` | `aws_iam_role_policy_attachment.chatbot_read_only` | Attaches `ReadOnlyAccess` to the Chatbot role |
| `notifications.tf` | `aws_chatbot_slack_channel_configuration.slack` | AWS Chatbot configuration mapping the Slack workspace and channel |
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

Create a `terraform.tfvars` file:

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

### Trigger an immediate evaluation

```bash
aws configservice start-config-rules-evaluation \
  --config-rule-names eks-secrets-encrypted \
  --region eu-west-2
```

### View current compliance status

```bash
aws configservice get-compliance-details-by-config-rule \
  --config-rule-name eks-secrets-encrypted \
  --region eu-west-2
```

**Expected output** (since `encryption_config` is disabled in `eks.tf`):

```json
{
  "EvaluationResults": [
    {
      "ComplianceType": "NON_COMPLIANT",
      "EvaluationResultIdentifier": {
        "EvaluationResultQualifier": {
          "ConfigRuleName": "eks-secrets-encrypted",
          "ResourceType": "AWS::EKS::Cluster",
          "ResourceId": "my-cluster"
        }
      }
    }
  ]
}
```

### Verify the EKS encryption configuration

```bash
aws eks describe-cluster \
  --name my-cluster \
  --region eu-west-2 \
  --query "cluster.encryptionConfig"
```

For the initial test deployment, this should return `null` because `encryption_config` is set to `null` in [eks.tf](./eks.tf).

### Verify your SNS subscription is confirmed

```bash
# Get the SNS topic ARN from Terraform outputs
SNS_TOPIC_ARN=$(terraform output -raw sns_topic_arn)

# List subscriptions to the topic
aws sns list-subscriptions-by-topic \
  --topic-arn $SNS_TOPIC_ARN \
  --region eu-west-2 \
  --output table
```

Expected output should show your email address with a status of `PendingConfirmation` (until you confirm the email) or `Confirmed`.

### Making the cluster COMPLIANT

To make the cluster compliant, configure the `encryption_config` block in [eks.tf](./eks.tf) with a valid KMS key ARN and run `terraform apply`. The AWS Config evaluation will change the status to `COMPLIANT`.

Example configuration:

```hcl
encryption_config = {
  resources        = ["secrets"]
  provider_key_arn = "arn:aws:kms:eu-west-2:ACCOUNT_ID:key/KEY_ID"
}
```

After `terraform apply`, verify that the cluster references the KMS key:

```bash
aws eks describe-cluster \
  --name my-cluster \
  --region eu-west-2 \
  --query "cluster.encryptionConfig"
```

---

## Troubleshooting

### No alert email received

1. Verify email subscription confirmation has been clicked (sender is `no-reply@sns.amazonaws.com`).
2. EventBridge only triggers on a compliance state transition, such as `INSUFFICIENT_DATA` to `NON_COMPLIANT`. If the rule was already non-compliant, you will not receive a second email.
3. Confirm the EventBridge rule exists: `aws events describe-rule --name eks-secrets-compliance-rule --region eu-west-2`

### `InvalidRequestException: Slack workspace not authorized`

AWS Chatbot Slack configurations require a one-time manual OAuth flow in the AWS Console before Terraform can manage them. See [Slack Authorization Setup](#slack-authorization-setup) above.

### `ResourceInUseException` when changing encryption

EKS secrets encryption is a cluster-level setting. If AWS rejects an encryption update because the cluster is still updating, wait until the cluster status is `ACTIVE` and rerun `terraform apply`:

```bash
aws eks describe-cluster \
  --name my-cluster \
  --region eu-west-2 \
  --query "cluster.status"
```

### Compliance still shows `NON_COMPLIANT`

1. Confirm [eks.tf](./eks.tf) has `encryption_config` configured with a KMS key ARN and has been applied.
2. Run the command below and confirm the cluster has an `encryptionConfig` with `resources = ["secrets"]` and a KMS key provider ARN:

```bash
aws eks describe-cluster --name my-cluster --region eu-west-2 --query "cluster.encryptionConfig"
```
3. Trigger a fresh Config evaluation with `aws configservice start-config-rules-evaluation --config-rule-names eks-secrets-encrypted --region eu-west-2`.
