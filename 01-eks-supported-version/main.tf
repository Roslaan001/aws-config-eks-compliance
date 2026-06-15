provider "aws" {
  region = "eu-west-2"
}



module "aws-config" {
  source                           = "cloudposse/config/aws"
  version                          = "2.0.0"
  name                             = "aws-config"
  s3_bucket_id                     = aws_s3_bucket.config.id
  global_resource_collector_region = "eu-west-2"
  s3_bucket_arn                    = aws_s3_bucket.config.arn

  create_sns_topic = false
  create_iam_role  = true

  recording_mode = {
    recording_frequency = "CONTINUOUS"
  }

  managed_rules = {
    eks-cluster-supported-version = {
      description = "Checks if an Amazon Elastic Kubernetes Service (EKS) cluster is running a supported Kubernetes version. This rule is NON_COMPLIANT if an EKS cluster is running an unsupported version (less than the parameter 'oldestVersionSupported').",
      identifier  = "EKS_CLUSTER_SUPPORTED_VERSION",
      enabled     = true
      tags        = { "eks-test" = "true" }
      input_parameters = {
        "oldestVersionSupported" = "1.32"
      }
    }
  }
}
