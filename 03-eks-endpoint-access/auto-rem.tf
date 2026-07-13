# ==============================================================================
# AUTOMATED COMPLIANCE REMEDIATION (Optional)
# ==============================================================================
# To enable automated remediation for EKS public endpoint access, uncomment
# this entire block, then run `terraform apply`.
# ==============================================================================

/*
# 1. Custom SSM Document to execute the EKS Update API call to restrict endpoint access
resource "aws_ssm_document" "eks_endpoint_remediation" {
  name          = "Remediate-DisableEksPublicEndpoint"
  document_type = "Automation"

  content = jsonencode({
    description   = "Disables public API endpoint access and enables private access for a non-compliant EKS cluster."
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
        name   = "DisablePublicEndpoint"
        action = "aws:executeAwsApi"
        inputs = {
          Service = "eks"
          Api     = "UpdateClusterConfig"
          name    = "{{ ClusterName }}"
          resourcesVpcConfig = {
            endpointPublicAccess  = false
            endpointPrivateAccess = true
          }
        }
      }
    ]
  })
}

# 2. IAM Role giving Systems Manager permission to update EKS configurations
resource "aws_iam_role" "remediation_role" {
  name = "eks-endpoint-remediation-role"

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
  name = "eks-endpoint-remediation-policy"
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
resource "aws_config_remediation_configuration" "eks_endpoint_auto_fix" {
  config_rule_name = "eks-endpoint-no-public-access"

  target_type = "SSM_DOCUMENT"
  target_id   = aws_ssm_document.eks_endpoint_remediation.name

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
*/

