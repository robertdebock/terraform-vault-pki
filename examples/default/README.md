# Default

This scenario mimics an external root-CA as described [here](https://learn.hashicorp.com/tutorials/vault/pki-engine?in=vault/secrets-management).

## Generate root CA

```shell
# Enable the PKI secrets engine for the root-CA.
vault secrets enable -path=pki pki

# Set the TTL to 10 years.
vault secrets tune -max-lease-ttl=87600h pki

# Generate a root-CA, save the certificate.
vault write -field=certificate pki/root/generate/internal \
  common_name="example.com" \
  ttl=87600h > CA_cert.crt

# Configure the CA publication endpoints.
vault write pki/config/urls \
  issuing_certificates="$VAULT_ADDR/v1/pki/ca" \
  crl_distribution_points="$VAULT_ADDR/v1/pki/crl"
```

## Generate the intermediate-CA.

```shell
# Enable the PKI secrets engine for the intermediate-CA.
vault secrets enable -path=pki_int pki

# Set the TTL to 5 years.
vault secrets tune -max-lease-ttl=43800h pki_int

# Create a certificate signing request.
vault write -format=json pki_int/intermediate/generate/internal \
  common_name="example.com Intermediate Authority" \
  | jq -r '.data.csr' > pki_intermediate.csr

# Let the root-CA sign the CSR.
vault write -format=json pki/root/sign-intermediate csr=@pki_intermediate.csr \
  format=pem_bundle ttl="43800h" \
  | jq -r '.data.certificate' > intermediate.cert.pem

# Write the signed intermediate certificate in the the intermediate-CA.
vault write pki_int/intermediate/set-signed certificate=@intermediate.cert.pem
```

## Configure the intermediate-CA

```shell
vault write pki_int/roles/example-dot-com \
  allowed_domains="example.com" \
  allow_subdomains=true \
  max_ttl="720h"
```

## Request a certificate

```shell
vault write pki_int/issue/example-dot-com common_name="test.example.com" ttl="24h"
```
