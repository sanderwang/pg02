
resource "aws_secretsmanager_secret" "weave-gitops" {
  name = "pg02/kubenuts/weave-gitops"
}

resource "aws_secretsmanager_secret_version" "weave-gitops" {
  secret_id     = aws_secretsmanager_secret.weave-gitops.id
  secret_string = jsonencode({
    admin-username      = "CHANGE_ME"
    admin-password-hash = "CHANGE_ME"
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}
