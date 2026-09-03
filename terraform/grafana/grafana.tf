resource "aws_secretsmanager_secret" "grafana" {
  name                    = "pg02/telemetry/grafana"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "grafana" {
  secret_id     = aws_secretsmanager_secret.grafana.id
  secret_string = jsonencode({
    admin-user     = "CHANGE_ME"
    admin-password = "CHANGE_ME"
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}
