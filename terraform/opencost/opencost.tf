data "aws_eks_cluster" "this" {
  name = "eks-playground"
}

data "aws_iam_openid_connect_provider" "this" {
  url = data.aws_eks_cluster.this.identity[0].oidc[0].issuer
}

data "aws_iam_policy_document" "opencost-trust" {
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
      values   = ["system:serviceaccount:telemetry:opencost"]
    }

    condition {
      test     = "StringEquals"
      variable = "${data.aws_iam_openid_connect_provider.this.url}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "opencost-access" {
  statement {
    effect    = "Allow"
    actions   = ["pricing:GetProducts", "ec2:DescribeSpotPriceHistory"]
    resources = ["*"]
  }
}

resource "aws_iam_role" "opencost" {
  name               = "pg02-opencost"
  assume_role_policy = data.aws_iam_policy_document.opencost-trust.json
}

resource "aws_iam_role_policy" "opencost-access" {
  name   = "pricing-access"
  role   = aws_iam_role.opencost.id
  policy = data.aws_iam_policy_document.opencost-access.json
}
