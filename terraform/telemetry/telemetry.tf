data "aws_eks_cluster" "this" {
  name = "eks-playground"
}

data "aws_iam_openid_connect_provider" "this" {
  url = data.aws_eks_cluster.this.identity[0].oidc[0].issuer
}

data "aws_iam_policy_document" "telemetry-secret-store-trust" {
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
      values   = ["system:serviceaccount:telemetry:telemetry-secret-store"]
    }

    condition {
      test     = "StringEquals"
      variable = "${data.aws_iam_openid_connect_provider.this.url}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "telemetry-secret-store-access" {
  statement {
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
    resources = ["arn:aws:secretsmanager:us-west-2:472882997329:secret:pg02/telemetry/*"]
  }
}

resource "aws_iam_role" "telemetry-secret-store" {
  name               = "pg02-eso-telemetry"
  assume_role_policy = data.aws_iam_policy_document.telemetry-secret-store-trust.json
}

resource "aws_iam_role_policy" "telemetry-secret-store-access" {
  name   = "secrets-manager-access"
  role   = aws_iam_role.telemetry-secret-store.id
  policy = data.aws_iam_policy_document.telemetry-secret-store-access.json
}
