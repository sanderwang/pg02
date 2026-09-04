data "aws_eks_cluster" "this" {
  name = "eks-playground"
}

data "aws_iam_openid_connect_provider" "this" {
  url = data.aws_eks_cluster.this.identity[0].oidc[0].issuer
}

data "aws_iam_policy_document" "linkerd-eso-trust" {
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
      values   = ["system:serviceaccount:linkerd:linkerd-secret-store"]
    }

    condition {
      test     = "StringEquals"
      variable = "${data.aws_iam_openid_connect_provider.this.url}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "linkerd-eso-access" {
  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
    ]
    resources = ["arn:aws:secretsmanager:us-west-2:472882997329:secret:pg02-linkerd-*"]
  }
}

resource "aws_iam_role" "linkerd-eso" {
  name               = "pg02-eso-linkerd"
  assume_role_policy = data.aws_iam_policy_document.linkerd-eso-trust.json
}

resource "aws_iam_role_policy" "linkerd-eso-access" {
  name   = "secrets-manager-access"
  role   = aws_iam_role.linkerd-eso.id
  policy = data.aws_iam_policy_document.linkerd-eso-access.json
}
