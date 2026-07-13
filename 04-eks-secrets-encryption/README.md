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

**Key design decision:** The `cloudposse/config/aws` module's built-in SNS topic is disabled (`create_sns_topic = false`). A custom SNS topic is provisioned in `notifications.tf` and fed exclusively via an EventBridge rule that filters for `Config Rules Compliance Change` events — preventing S3 delivery logs from flooding your inbox.

---

## Resources Created

| File | Resource / Data Source | Description |
|---|---|---|
| `main.tf` | `module.aws-config` | AWS Config recorder, delivery channel, and the `EKS_SECRETS_ENCRYPTED` rule |
| `eks.tf` | `data.aws_vpc.default` | Data source looking up the default VPC |
| `eks.tf` | `data.aws_subnets.default` | Data source looking up subnets in the default VPC |
| `eks.tf` | `data.aws_iam_role.lab_role` | Data source looking up the existing `LabRole` IAM role |
| `eks.tf` | `module.eks` | EKS cluster (`my-cluster`, Kubernetes `1.35`) with secrets encryption initially disabled for testing |
| `s3-bucket.tf` | `data.aws_caller_identity.current` | Data source used to make the S3 bucket name unique per account |
| `s3-bucket.tf` | `aws_s3_bucket.config` | S3 bucket for AWS Config configuration history snapshots |
| `s3-bucket.tf` | `aws_s3_bucket_public_access_block.config` | Blocks public access to the AWS Config history bucket |
| `s3-bucket.tf` | `data.aws_iam_policy_document.config_bucket_policy` | Generates the S3 bucket policy JSON |
| `s3-bucket.tf` | `aws_s3_bucket_policy.config` | Bucket policy granting AWS Config write access |
| `variables.tf` | — | Declares input variables for the email and Slack configuration |
| `notifications.tf` | `aws_sns_topic.compliance_alerts` | Custom SNS topic: `eks-secrets-encryption-compliance-alerts` |
| `notifications.tf` | `data.aws_iam_policy_document.sns_publish_policy` | Generates the SNS topic policy JSON |
| `notifications.tf` | `aws_sns_topic_policy.compliance` | Allows EventBridge to publish to the SNS topic |
| `notifications.tf` | `aws_cloudwatch_event_rule.compliance` | EventBridge rule matching `Config Rules Compliance Change` |
| `notifications.tf` | `aws_cloudwatch_event_target.sns` | Routes EventBridge events to the SNS topic |
| `notifications.tf` | `aws_sns_topic_subscription.email` | Email subscription to the SNS topic |
| `notifications.tf` | `aws_iam_role.chatbot` | IAM role assumed by AWS Chatbot |
| `notifications.tf` | `aws_iam_role_policy_attachment.chatbot_read_only` | Attaches `ReadOnlyAccess` to the Chatbot role |
| `notifications.tf` | `aws_chatbot_slack_channel_configuration.slack` | AWS Chatbot configuration mapping the Slack workspace and channel |
| `output.tf` | — | Stack outputs (recorder ID, bucket name, ARNs, rule name, EKS details) |
| `terraform.tfvars` | — | Local variables override values file (ignored by Git) |

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

| Variable | Type | Default | Description |
|---|---|---|---|
| `alert_email` | `string` | `"your-email@example.com"` | Email address to receive compliance alerts |
| `slack_team_id` | `string` | `"T0000000000"` | Slack Workspace ID (for optional Chatbot integration) |
| `slack_channel_id` | `string` | `"C0000000000"` | Slack Channel ID (for optional Chatbot integration) |

Create a `terraform.tfvars` file to override the defaults:

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

> If AWS returns `LimitExceededException`, the service is rate-limiting the request. Wait a few minutes and retry once; repeated back-to-back calls can trigger throttling. You can still inspect the current state with the compliance-status command below.

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

| Problem | Cause | Fix |
|---|---|---|
| No alert email received after re-evaluation | SNS email subscription is pending confirmation, or no state transition occurred | 1. Check your **spam/junk folder** (sender: `no-reply@sns.amazonaws.com`). <br>2. Confirm the subscription (see [Checking Compliance](#checking-compliance)). <br>3. EventBridge triggers only on state transition. If the resource was already non-compliant, trigger a fresh check after changing EKS config. |
| `terraform apply` fails on `aws_chatbot_slack_channel_configuration` | Slack workspace is not authorized in AWS Chatbot | Open **AWS Chatbot → Configured clients → Slack → Configure client** in the AWS Console and complete authorization. See [Slack Authorization Setup](#slack-authorization-setup). |
| `Error: Configuration recorder already exists` | A Config recorder is already enabled in this region / account | AWS only allows one configuration recorder per region. You must import the existing recorder to manage it via Terraform or delete it before applying. |
| Slack messages not appearing in the channel | Chatbot lacks role permissions, or workspace/channel IDs are incorrect, or the bot isn't in the channel | 1. Double-check your `slack_team_id` and `slack_channel_id` variables. <br>2. Invite the AWS Chatbot application to your Slack channel by typing `/invite @aws` in Slack. |
| `BucketAlreadyExists` or name collision during apply | S3 bucket names must be globally unique | By default, the S3 bucket name uses the format `aws-config-eks-secrets-bucket-${data.aws_caller_identity.current.account_id}`. If another user in your account has taken the name, modify the bucket naming scheme in `s3-bucket.tf`. |
| `ResourceInUseException` when changing encryption | EKS secrets encryption is a cluster-level setting; update can only run when cluster is `ACTIVE` | If EKS rejects an encryption update because the cluster is updating, wait until the status is active and rerun apply: `aws eks describe-cluster --name my-cluster --region eu-west-2 --query "cluster.status"`. |
| Compliance still shows `NON_COMPLIANT` after enabling encryption | AWS Config has not re-evaluated yet, or configuration was not fully applied | 1. Verify [eks.tf](./eks.tf) has `encryption_config` configured and applied. <br>2. Run `aws eks describe-cluster --name my-cluster --region eu-west-2 --query "cluster.encryptionConfig"` to confirm settings. <br>3. Trigger evaluation manually: `aws configservice start-config-rules-evaluation --config-rule-names eks-secrets-encrypted --region eu-west-2`. |
| EKS Cluster creation takes too long or fails | Network or IAM issues | Verify that your AWS CLI user has permissions to create VPCs, IAM roles, and EKS resources. Cluster creation can take 10-20 minutes normally. |
