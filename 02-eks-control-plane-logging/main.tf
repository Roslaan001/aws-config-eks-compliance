provider "aws" {
  region = "eu-west-2"
}

module "aws-config" {
  source                           = "cloudposse/config/aws"
  version                          = "2.0.0"
  name                             = "aws-config-logging"
  s3_bucket_id                     = aws_s3_bucket.config.id
  global_resource_collector_region = "eu-west-2"
  s3_bucket_arn                    = aws_s3_bucket.config.arn

  create_sns_topic = false
  create_iam_role  = true

  recording_mode = {
    recording_frequency = "CONTINUOUS"
  }

  managed_rules = {
    eks-cluster-log-enabled = {
      description = "Checks if an Amazon Elastic Kubernetes Service (Amazon EKS) cluster is configured with logging enabled. The rule is NON_COMPLIANT if logging for Amazon EKS clusters is not enabled or if logging is not enabled with the log type mentioned.",
      identifier  = "EKS_CLUSTER_LOG_ENABLED",
      enabled     = true
      tags        = { "eks-test" = "true" }
      input_parameters = {
        "logTypes" = "api,audit,authenticator,controllerManager,scheduler"
      }
    }
  }
}
