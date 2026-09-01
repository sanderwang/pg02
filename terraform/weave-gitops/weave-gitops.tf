resource "aws_secretsmanager_secret" "weave-gitops-secrets" {
  for_each = toset([
    "admin-username",
    "admin-password-hash",
  ])

  name = "pg02/kubenuts/weave-gitops/${each.value}"
}
