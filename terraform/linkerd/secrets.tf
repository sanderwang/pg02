resource "aws_secretsmanager_secret" "linkerd-root-cert" {
  name = "pg02/linkerd/root-cert"
}

resource "aws_secretsmanager_secret_version" "linkerd-root-cert" {
  secret_id = aws_secretsmanager_secret.linkerd-root-cert.id
  secret_string = jsonencode({
    "cert.pem" = tls_self_signed_cert.linkerd-certs["root"].cert_pem
    "key.pem" = tls_private_key.linkerd-cert-keys["root"].private_key_pem
  })
}

resource "aws_secretsmanager_secret" "linkerd-webhook-issuer-cert" {
  name = "pg02/linkerd/webhook-issuer-cert"
}

resource "aws_secretsmanager_secret_version" "linkerd-webhook-issuer-cert" {
  secret_id = aws_secretsmanager_secret.linkerd-webhook-issuer-cert.id
  secret_string = jsonencode({
    "cert.pem"     = tls_self_signed_cert.linkerd-certs["webhook-issuer"].cert_pem
    "key.pem" = tls_private_key.linkerd-cert-keys["webhook-issuer"].private_key_pem
  })
}
