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
