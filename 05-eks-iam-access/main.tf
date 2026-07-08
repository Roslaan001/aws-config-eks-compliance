provider "aws" {
  region = "eu-west-2"
}

module "aws-config" {
  source                           = "cloudposse/config/aws"
  version                          = "2.0.0"
  name                             = "aws-config-iam"
  s3_bucket_id                     = aws_s3_bucket.config.id
  global_resource_collector_region = "eu-west-2"
  s3_bucket_arn                    = aws_s3_bucket.config.arn

  create_sns_topic = false
  create_iam_role  = true

  recording_mode = {
    recording_frequency = "CONTINUOUS"
  }

  managed_rules = {
    iam-policy-no-statements-with-admin-access = {
      description      = "Checks whether the customer managed IAM policies that you create do not have statements that grant administrator access (Action=* and Resource=*).",
      identifier       = "IAM_POLICY_NO_STATEMENTS_WITH_ADMIN_ACCESS",
      enabled          = true
      tags             = { "eks-test" = "true" }
      input_parameters = null
    }
  }
}
