# Part 05 — Auditing EKS IAM and Access Configurations

> Part of the [aws-config-eks](../README.md) series — enforcing EKS compliance with AWS Config.

This project enforces IAM security best practices across your EKS environment by auditing customer-managed IAM policies for wildcard administrative privileges. It is intentionally designed as a monitoring and alerting example: it creates a deliberately non-compliant policy so you can observe AWS Config reporting and notification behavior in practice.

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

| AWS Config Rule | `IAM_POLICY_NO_STATEMENTS_WITH_ADMIN_ACCESS` |
|---|---|
| **COMPLIANT** | All customer-managed IAM policies do not contain wildcard admin configurations (`Action = "*"` and `Resource = "*"`) |
| **NON_COMPLIANT** | One or more customer-managed IAM policies contain wildcard admin configurations |
| **Evaluation trigger** | On configuration change + periodic |

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                     AWS Account (eu-west-2)             │
│                                                         │
│  ┌──────────────────┐  evaluates  ┌──────────────────┐ │
│  │   IAM Policy     │ ──────────► │  AWS Config Rule │ │
│  │  (wildcard admin)│             │  iam-policy-no-  │ │
│  │  backdoor        │             │  statements-with-│ │
│  └──────────────────┘             │  admin-access    │ │
│                                   └────────┬─────────┘ │
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

## Resources Created

| File | Resource | Description |
|---|---|---|
| `main.tf` | `module.aws-config` | AWS Config recorder, delivery channel, and the `IAM_POLICY_NO_STATEMENTS_WITH_ADMIN_ACCESS` rule |
| `iam-violation.tf` | `aws_iam_policy.wildcard_admin_backdoor` | Deliberately non-compliant wildcard admin policy containing `Action = "*"` and `Resource = "*"` |
| `s3-bucket.tf` | `data.aws_caller_identity.current` | Data source used to make the S3 bucket name unique per account |
| `s3-bucket.tf` | `aws_s3_bucket.config` | S3 bucket for AWS Config history |
| `s3-bucket.tf` | `aws_s3_bucket_public_access_block.config` | Blocks all public access to the Config S3 bucket |
| `s3-bucket.tf` | `data.aws_iam_policy_document.config_bucket_policy` | IAM policy document granting AWS Config access to the bucket |
| `s3-bucket.tf` | `aws_s3_bucket_policy.config` | Bucket policy allowing AWS Config to deliver objects |
| `notifications.tf` | `aws_sns_topic.compliance_alerts` | Custom SNS topic for compliance alerts |
| `notifications.tf` | `aws_sns_topic_policy.compliance` | SNS topic policy allowing EventBridge to publish |
| `notifications.tf` | `data.aws_iam_policy_document.sns_publish_policy` | IAM policy document for the SNS publish permission |
| `notifications.tf` | `aws_cloudwatch_event_rule.compliance` | EventBridge rule matching Config compliance state changes |
| `notifications.tf` | `aws_cloudwatch_event_target.sns` | EventBridge target routing compliance events to the SNS topic |
| `notifications.tf` | `aws_sns_topic_subscription.email` | Email subscription on the SNS topic |
| `notifications.tf` | `aws_iam_role.chatbot` | IAM role assumed by AWS Chatbot |
| `notifications.tf` | `aws_iam_role_policy_attachment.chatbot_read_only` | Attaches `ReadOnlyAccess` to the Chatbot role |
| `notifications.tf` | `aws_chatbot_slack_channel_configuration.slack` | AWS Chatbot Slack channel configuration linked to the SNS topic |
| `variables.tf` | — | Input variables for alerting and Slack integration |
| `output.tf` | — | Stack outputs (recorder ID, bucket name, ARNs, rule name, violation policy) |
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
| `chatbot_slack_arn` | The ARN of the AWS Chatbot Slack channel configuration |
| `config_rule_name` | The AWS Config managed rule deployed by this stack |
| `violation_policy_name` | The name of the wildcard admin policy created for testing |
| `violation_policy_arn` | The ARN of the wildcard admin policy created for testing |

---

## Checking Compliance

### Trigger an immediate evaluation

```bash
aws configservice start-config-rules-evaluation \
  --config-rule-names iam-policy-no-statements-with-admin-access \
  --region eu-west-2
```

### View current compliance status

```bash
aws configservice get-compliance-details-by-config-rule \
  --config-rule-name iam-policy-no-statements-with-admin-access \
  --region eu-west-2
```

**Expected output** (due to presence of the simulated backdoor policy):

```json
{
  "EvaluationResults": [
    {
      "ComplianceType": "NON_COMPLIANT",
      "EvaluationResultIdentifier": {
        "EvaluationResultQualifier": {
          "ConfigRuleName": "iam-policy-no-statements-with-admin-access",
          "ResourceType": "AWS::IAM::Policy",
          "ResourceId": "ANPAXXXXXXXXXXXXXXXXXXXXX"
        }
      }
    }
  ]
}
```

### Remediating the IAM Policy

To restore compliance, delete the non-compliant policy using the console or the CLI:

```bash
aws iam delete-policy --policy-arn <violation_policy_arn>
```

---

## Troubleshooting

| Problem | Cause | Fix |
|---|---|---|
| `terraform apply` fails on `aws_chatbot_slack_channel_configuration` | The one-time Slack OAuth flow has not been completed in the AWS Console | Open **AWS Chatbot → Configured clients → Slack → Configure client** and complete the authorization. See [Slack Authorization Setup](#slack-authorization-setup). |
| No email notifications received after deployment | The SNS email subscription is pending confirmation | Check the inbox for `alert_email` and click the **Confirm subscription** link sent by AWS. |
| `Error: Configuration recorder already exists` | Only one Config recorder is allowed per region per account | Import the existing recorder (`terraform import`) or remove it before deploying. |
| EventBridge rule never triggers | AWS Config has not re-evaluated the rule yet | Manually trigger an evaluation — see [Trigger an immediate evaluation](#trigger-an-immediate-evaluation). |
| Slack messages not appearing | Chatbot role lacks permissions, or the channel ID is wrong | Verify `slack_channel_id` is correct and that the Chatbot app has been invited to the channel (`/invite @aws`). |
