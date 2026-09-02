data "aws_eks_cluster" "this" {
  name = "eks-playground"
}

data "aws_iam_openid_connect_provider" "this" {
  url = data.aws_eks_cluster.this.identity[0].oidc[0].issuer
}

data "aws_iam_policy_document" "argocd-secret-store-trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.this.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${data.aws_iam_openid_connect_provider.this.url}:sub"
      values   = ["system:serviceaccount:argocd:argocd-secret-store"]
    }

    condition {
      test     = "StringEquals"
      variable = "${data.aws_iam_openid_connect_provider.this.url}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "argocd-secret-store-access" {
  statement {
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
    resources = ["arn:aws:secretsmanager:us-west-2:472882997329:secret:pg02/argocd/*"]
  }
}

resource "aws_iam_role" "argocd-secret-store" {
  name               = "pg02-eso-argocd"
  assume_role_policy = data.aws_iam_policy_document.argocd-secret-store-trust.json
}

resource "aws_iam_role_policy" "argocd-secret-store-access" {
  name   = "secrets-manager-access"
  role   = aws_iam_role.argocd-secret-store.id
  policy = data.aws_iam_policy_document.argocd-secret-store-access.json
}

resource "aws_secretsmanager_secret" "argocd-secrets" {
  for_each = toset([
    "argocd-secret",
  ])

  name                    = "pg02/argocd/${each.value}"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "argocd-secret" {
  secret_id     = aws_secretsmanager_secret.argocd-secrets["argocd-secret"].id
  secret_string = jsonencode({
    admin-password-hash  = "CHANGE_ME"
    admin-password-mtime = "CHANGE_ME"
    server-secret-key    = "CHANGE_ME"
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}
