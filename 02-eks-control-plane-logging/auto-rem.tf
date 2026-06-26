# 1. the custom SSM document to execute the EKS pdate API call
resource "aws_ssm_document" "eks_logging_remediation" {
  name          = "Remediate-EnableEksLogging"
  document_type = "Automation"

  content = jsonencode({
    description   = "Enables all control plane logging types for a non-compliant EKS cluster."
    schemaVersion = "0.3"
    assumeRole    = "{{ AutomationAssumeRole }}"
    parameters = {
      ClusterName = {
        type        = "String"
        description = "The name of the non-compliant EKS Cluster."
      }
      AutomationAssumeRole = {
        type        = "String"
        description = "The ARN of the IAM role that allows Automation to perform actions."
      }
    }
    mainSteps = [
      {
        name   = "EnableEKSLogging"
        action = "aws:executeAwsApi"
        inputs = {
          Service = "eks"
          Api     = "UpdateClusterConfig"
          name    = "{{ ClusterName }}"
          logging = {
            clusterLogging = [
              {
                types   = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
                enabled = true
              }
            ]
          }
        }
      }
    ]
  })
}

# 2. IAM Role giving Systems Manager permission to update EKS
resource "aws_iam_role" "remediation_role" {
  name = "eks-config-remediation-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = { Service = "ssm.amazonaws.com" }
      }
    ]
  })
}

# 3. Policy attached to the IAM Role for EKS configuration access
resource "aws_iam_role_policy" "eks_remediation_policy" {
  name = "eks-logging-remediation-policy"
  role = aws_iam_role.remediation_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "eks:UpdateClusterConfig"
        Resource = "*"
      }
    ]
  })
}

# 4. Bind the remediation to the AWS Config Rule
resource "aws_config_remediation_configuration" "eks_logging_auto_fix" {
  config_rule_name = "eks-cluster-log-enabled"

  target_type = "SSM_DOCUMENT"
  target_id   = aws_ssm_document.eks_logging_remediation.name

  automatic                  = true
  maximum_automatic_attempts = 3
  retry_attempt_seconds      = 60

  parameter {
    name         = "AutomationAssumeRole"
    static_value = aws_iam_role.remediation_role.arn
  }

  parameter {
    name           = "ClusterName"
    resource_value = "RESOURCE_ID"
  }

  depends_on = [
    module.aws-config,
    aws_iam_role_policy.eks_remediation_policy
  ]
}
