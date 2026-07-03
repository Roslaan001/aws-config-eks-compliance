provider "aws" {
  region = "eu-west-2"
}

module "aws-config" {
  source                           = "cloudposse/config/aws"
  version                          = "2.0.0"
  name                             = "aws-config-endpoint"
  s3_bucket_id                     = aws_s3_bucket.config.id
  global_resource_collector_region = "eu-west-2"
  s3_bucket_arn                    = aws_s3_bucket.config.arn

  create_sns_topic = false
  create_iam_role  = true

  recording_mode = {
    recording_frequency = "CONTINUOUS"
  }

  managed_rules = {
    eks-endpoint-no-public-access = {
      description      = "Checks whether Amazon EKS cluster endpoint access is configured. The rule is NON_COMPLIANT if the EKS cluster endpoint public access is enabled.",
      identifier       = "EKS_ENDPOINT_NO_PUBLIC_ACCESS",
      enabled          = true
      tags             = { "eks-test" = "true" }
      input_parameters = {}
    }
  }
}
