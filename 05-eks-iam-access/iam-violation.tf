# A non-compliant Customer Managed IAM Policy containing administrative wildcard permissions.
# This policy violates IAM_POLICY_NO_STATEMENTS_WITH_ADMIN_ACCESS.
resource "aws_iam_policy" "wildcard_admin_backdoor" {
  name        = "eks-unauthorized-admin-backdoor"
  description = "A simulated backdoor policy that violates least-privilege auditing rules."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "*"
        Resource = "*"
      }
    ]
  })
}
