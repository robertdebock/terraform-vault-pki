# Create a key for the root-CA.
resource "tls_private_key" "ca_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Create a certificate for the root-CA.
resource "tls_self_signed_cert" "ca_cert" {
  private_key_pem = tls_private_key.ca_key.private_key_pem
  subject {
    common_name         = "Root CA"
    organization        = "Adfinis"
    organizational_unit = "Infra"
    street_address      = ["Hortensiastraat 10"]
    locality            = "Hengelo"
    province            = "Overijssel"
    country             = "NL"
    postal_code         = "7555 CS"
  }
  validity_period_hours = 175200 # 20 years
  allowed_uses = [
    "cert_signing",
    "crl_signing"
  ]
  is_ca_certificate = true
}

# Mount the pki secrets engine for the root-CA.
resource "vault_mount" "root" {
  path                      = "pki"
  type                      = "pki"
  default_lease_ttl_seconds = 3600
  max_lease_ttl_seconds     = 315360000 # 10 years
}

resource "vault_pki_secret_backend_config_ca" "ca_config" {
  backend    = vault_mount.root.path
  pem_bundle = join("", [tls_private_key.ca_key.private_key_pem, tls_self_signed_cert.ca_cert.cert_pem])
}

# Mount the pki secrets engine for the intermedate-CA.
resource "vault_mount" "intermediate" {
  path                      = "pki-intermediate"
  type                      = "pki"
  default_lease_ttl_seconds = 3600
  max_lease_ttl_seconds     = 315360000 # 10 years
}

# Create a certificate signing request for the intermedate-CA.
resource "vault_pki_secret_backend_intermediate_cert_request" "intermediate" {
  backend            = vault_mount.intermediate.path
  type               = "internal"
  common_name        = "MY Intermediate Certificate"
  format             = "pem"
  private_key_format = "der"
  key_type           = "rsa"
  key_bits           = "4096"
}

# Sign the certificate signing request with the root-CA.
resource "vault_pki_secret_backend_root_sign_intermediate" "intermediate" {
  backend              = vault_mount.root.path
  csr                  = vault_pki_secret_backend_intermediate_cert_request.intermediate.csr
  common_name          = "MY Intermediate Certificate"
  exclude_cn_from_sans = true
  ou                   = "Development"
  organization         = "Adfinis"
  ttl                  = 252288000
}

# Store the signed certificate.
resource "vault_pki_secret_backend_intermediate_set_signed" "intermediate" {
  backend     = vault_mount.intermediate.path
  certificate = join("\n", [vault_pki_secret_backend_root_sign_intermediate.intermediate.certificate, tls_self_signed_cert.ca_cert.cert_pem])
}

# Create a role for generating certificates.
resource "vault_pki_secret_backend_role" "default" {
  backend            = vault_mount.intermediate.path
  name               = "server-cert-for-MY"
  allowed_domains    = ["example.com"]
  allow_subdomains   = true
  allow_glob_domains = false
  allow_any_name     = false
  enforce_hostnames  = true
  allow_ip_sans      = true
  server_flag        = true
  client_flag        = false
  ou                 = ["development"]
  organization       = ["Adfinis"]
  country            = ["NL"]
  locality           = ["Overijssel"]
  max_ttl = 63113904
  ttl      = 2592000
  no_store = true
}
