locals {
  linkerd_certs = {
    "root"           = "root.linkerd.cluster.local"
    "webhook-issuer" = "webhook.linkerd.cluster.local"
  }
}

resource "tls_private_key" "linkerd-cert-keys" {
  for_each = local.linkerd_certs

  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

resource "tls_self_signed_cert" "linkerd-certs" {
  for_each = local.linkerd_certs

  is_ca_certificate     = true
  dns_names             = [each.value]
  private_key_pem       = tls_private_key.linkerd-cert-keys[each.key].private_key_pem
  early_renewal_hours   = 30 * 24
  validity_period_hours = 10 * 365 * 24

  allowed_uses = [
    "cert_signing",
    "client_auth",
    "crl_signing",
    "ocsp_signing",
    "server_auth",
  ]

  subject {
    common_name = each.value
  }
}

data "aws_eks_cluster" "this" {
  name = "eks-playground"
}

data "aws_iam_openid_connect_provider" "this" {
  url = data.aws_eks_cluster.this.identity[0].oidc[0].issuer
}

data "aws_iam_policy_document" "linkerd-secret-store-trust" {
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

data "aws_iam_policy_document" "linkerd-secret-store-access" {
  statement {
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
    resources = ["arn:aws:secretsmanager:us-west-2:472882997329:secret:pg02/linkerd/*"]
  }
}

resource "aws_iam_role" "linkerd-secret-store" {
  name               = "pg02-eso-linkerd"
  assume_role_policy = data.aws_iam_policy_document.linkerd-secret-store-trust.json
}

resource "aws_iam_role_policy" "linkerd-secret-store-access" {
  name   = "secrets-manager-access"
  role   = aws_iam_role.linkerd-secret-store.id
  policy = data.aws_iam_policy_document.linkerd-secret-store-access.json
}

resource "aws_secretsmanager_secret" "linkerd-root-cert" {
  name = "pg02/linkerd/root-cert"
}

resource "aws_secretsmanager_secret_version" "linkerd-root-cert" {
  secret_id = aws_secretsmanager_secret.linkerd-root-cert.id
  secret_string = jsonencode({
    "cert.pem" = tls_self_signed_cert.linkerd-certs["root"].cert_pem
    "key.pem"  = tls_private_key.linkerd-cert-keys["root"].private_key_pem
  })
}

resource "aws_secretsmanager_secret" "linkerd-webhook-issuer-cert" {
  name = "pg02/linkerd/webhook-issuer-cert"
}

resource "aws_secretsmanager_secret_version" "linkerd-webhook-issuer-cert" {
  secret_id = aws_secretsmanager_secret.linkerd-webhook-issuer-cert.id
  secret_string = jsonencode({
    "cert.pem" = tls_self_signed_cert.linkerd-certs["webhook-issuer"].cert_pem
    "key.pem"  = tls_private_key.linkerd-cert-keys["webhook-issuer"].private_key_pem
  })
}
