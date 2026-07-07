provider "aws" {
  region = "eu-west-2"
}

module "aws-config" {
  source                           = "cloudposse/config/aws"
  version                          = "2.0.0"
  name                             = "aws-config-secrets"
  s3_bucket_id                     = aws_s3_bucket.config.id
  global_resource_collector_region = "eu-west-2"
  s3_bucket_arn                    = aws_s3_bucket.config.arn

  create_sns_topic = false
  create_iam_role  = true

  recording_mode = {
    recording_frequency = "CONTINUOUS"
  }

  managed_rules = {
    eks-secrets-encrypted = {
      description      = "Checks whether Amazon Elastic Kubernetes Service (Amazon EKS) clusters are configured to encrypt Kubernetes secrets using AWS KMS keys.",
      identifier       = "EKS_SECRETS_ENCRYPTED",
      enabled          = true
      tags             = { "eks-test" = "true" }
      input_parameters = {
        # Optional: Comma-separated list of approved KMS Key ARNs.
        # If left empty, any KMS key is evaluated as compliant.
        # kmsKeyArns = "arn:aws:kms:region:account-id:key/key-uuid"
      }
    }
  }
}
