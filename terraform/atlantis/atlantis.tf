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

resource "aws_secretsmanager_secret" "atlantis-github" {
  name                    = "pg02/kubenuts/atlantis"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "atlantis-github" {
  secret_id     = aws_secretsmanager_secret.atlantis-github.id
  secret_string = jsonencode({
    github-token          = "CHANGE_ME"
    github-webhook-secret = "CHANGE_ME"
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

resource "aws_wafv2_ip_set" "atlantis-webhook-github-ipv4" {
  name               = "pg02-atlantis-webhook-github-ipv4"
  scope              = "REGIONAL"
  ip_address_version = "IPV4"

  addresses = [
    # https://api.github.com/meta
    "192.30.252.0/22",
    "185.199.108.0/22",
    "140.82.112.0/20",
    "143.55.64.0/20",
  ]
}

resource "aws_wafv2_ip_set" "atlantis-webhook-github-ipv6" {
  name               = "pg02-atlantis-webhook-github-ipv6"
  scope              = "REGIONAL"
  ip_address_version = "IPV6"

  addresses = [
    # https://api.github.com/meta
    "2a0a:a440::/29",
    "2606:50c0::/32",
  ]
}

resource "aws_wafv2_web_acl" "atlantis-webhook" {
  name  = "pg02-atlantis-webhook"
  scope = "REGIONAL"

  default_action {
    block {}
  }

  rule {
    name     = "allow-github"
    priority = 1

    action {
      allow {}
    }

    statement {
      or_statement {
        statement {
          ip_set_reference_statement {
            arn = aws_wafv2_ip_set.atlantis-webhook-github-ipv4.arn
          }
        }
        statement {
          ip_set_reference_statement {
            arn = aws_wafv2_ip_set.atlantis-webhook-github-ipv6.arn
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = false
      metric_name                = "pg02-atlantis-webhook-allow"
      sampled_requests_enabled   = false
    }
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
