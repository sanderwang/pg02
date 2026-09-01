data "aws_eks_cluster" "this" {
  name = "eks-playground"
}

data "aws_iam_openid_connect_provider" "this" {
  url = data.aws_eks_cluster.this.identity[0].oidc[0].issuer
}

data "aws_route53_zone" "this" {
  name         = "pg02.narvar.qa"
  private_zone = false
}

data "aws_iam_policy_document" "cert-manager-trust" {
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
      values   = ["system:serviceaccount:cert-manager:cert-manager"]
    }

    condition {
      test     = "StringEquals"
      variable = "${data.aws_iam_openid_connect_provider.this.url}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "cert-manager-access" {
  statement {
    effect    = "Allow"
    actions   = ["route53:GetChange"]
    resources = ["arn:aws:route53:::change/*"]
  }

  statement {
    effect  = "Allow"
    actions = [
      "route53:ChangeResourceRecordSets",
      "route53:ListResourceRecordSets",
    ]
    resources = ["arn:aws:route53:::hostedzone/${data.aws_route53_zone.this.zone_id}"]

    condition {
      test     = "StringEquals"
      variable = "route53:ChangeResourceRecordSetsRecordTypes"
      values   = ["TXT"]
    }
  }

  statement {
    effect    = "Allow"
    actions   = ["route53:ListHostedZonesByName"]
    resources = ["*"]
  }
}

resource "aws_iam_role" "cert-manager" {
  name               = "pg02-cert-manager"
  assume_role_policy = data.aws_iam_policy_document.cert-manager-trust.json
}

resource "aws_iam_role_policy" "cert-manager-access" {
  name   = "route53-access"
  role   = aws_iam_role.cert-manager.id
  policy = data.aws_iam_policy_document.cert-manager-access.json
}
