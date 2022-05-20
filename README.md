# Vault PKI

Configure Vault to run as a PKI.

## Requesting certificates

```shell
vault write pki-intermediate/issue/server-cert-for-MY common_name="test.example.com" ttl="24h"
```

## Revoke a certificate

```shell
vault write pki-intermediate/revoke serial_number=5d:7f:f5:00:90:80:09:0f:20:e5:35:f8:95:3c:80:18:71:39:00:aa
```

## Download the revoked certificates

```shell
curl -H "X-Vault-Token: YoUrToKeN" http://127.0.0.1:8200/v1/pki/crl --output crl
```
