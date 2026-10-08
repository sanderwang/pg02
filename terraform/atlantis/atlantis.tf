data "aws_eks_cluster" "this" {
  name = "eks-playground"
}

data "aws_iam_openid_connect_provider" "this" {
  url = data.aws_eks_cluster.this.identity[0].oidc[0].issuer
}

data "aws_iam_policy_document" "atlantis-trust" {
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
      values   = ["system:serviceaccount:kubenuts:atlantis"]
    }

    condition {
      test     = "StringEquals"
      variable = "${data.aws_iam_openid_connect_provider.this.url}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "atlantis" {
  name               = "pg02-atlantis"
  assume_role_policy = data.aws_iam_policy_document.atlantis-trust.json
}

resource "aws_wafv2_web_acl" "atlantis-webhook" {
  name  = "pg02-atlantis-webhook"
  scope = "REGIONAL"

  default_action {
    block {}
  }

  visibility_config {
    cloudwatch_metrics_enabled = false
    metric_name                = "pg02-atlantis-webhook"
    sampled_requests_enabled   = false
  }
}

data "aws_lb" "atlantis-webhook" {
  tags = {
    "kubenuts/stack"     = "pg02"
    "kubenuts/namespace" = "kubenuts"
    "kubenuts/gateway"   = "atlantis-webhook"
  }
}

resource "aws_wafv2_web_acl_association" "atlantis-webhook" {
  resource_arn = data.aws_lb.atlantis-webhook.arn
  web_acl_arn  = aws_wafv2_web_acl.atlantis-webhook.arn
}
