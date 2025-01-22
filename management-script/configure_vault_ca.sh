#!/bin/bash

# Exit on any error
set -e

# Function to log messages
log() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $1"
}

log "Configuring Vault CA and SSL..."

# Wait for Vault to be ready
log "Waiting for Vault to be ready..."
sleep 10

# Enable PKI secrets engine in Vault
log "Enabling PKI secrets engine in Vault..."
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='root'

vault secrets enable pki
vault secrets tune -max-lease-ttl=8760h pki
vault write -field=certificate pki/root/generate/internal \
     common_name="$DOMAIN_NAME" \
     issuer_name="vault-ssl" \
     ttl=87600h key_type="rsa" key_bits="2048"> vault_ssl_ca.crt

vault write pki/roles/ssl-servers allow_any_name=true

vault write pki/config/urls issuing_certificates="$VAULT_ADDR/v1/pki/ca" crl_distribution_points="$VAULT_ADDR/v1/pki/crl"

# Generate Intermediate CA
log "Generating Intermediate CA..." 
vault secrets enable -path=pki_int pki
vault secrets tune -max-lease-ttl=43800h pki_int

vault write -format=json pki_int/intermediate/generate/internal \
     common_name="$DOMAIN_NAME Intermediate Authority" \
     issuer_name="$DOMAIN_NAME-intermediate" \
     | jq -r '.data.csr' > pki_intermediate.csr

vault write -format=json pki/root/sign-intermediate \
     issuer_ref="vault-ssl" \
     csr=@pki_intermediate.csr \
     format=pem_bundle ttl="43800h" \
     | jq -r '.data.certificate' > intermediate.cert.pem

vault write pki_int/intermediate/set-signed certificate=@intermediate.cert.pem


#Create a role for generating certificates
vault write pki_int/roles/$DOMAIN_NAME-dot-local \
     issuer_ref="$(vault read -field=default pki_int/config/issuers)" \
     allowed_domains="$DOMAIN_NAME" \
     allow_subdomains=true \
     max_ttl="8760h"



# Define the directory for certificates
CERT_DIR="$VAULT_COMPOSE_DIR/certs"
mkdir -p $CERT_DIR

# Generate a certificate for Vault
log "Generating a certificate for Vault..."
vault write -format=json pki_int/issue/$DOMAIN_NAME-dot-local \
common_name="vault-tls" ip_sans="127.0.0.1" | tee \
>(jq -r .data.certificate > $CERT_DIR/vault-tls-certificate.pem) \
>(jq -r .data.issuing_ca > $CERT_DIR/vault-tls-issuing-ca.pem) \
>(jq -r .data.private_key > $CERT_DIR/vault-tls-private-key.pem)

mkdir -p "$VAULT_COMPOSE_DIR/vault/config"
cat > "$VAULT_COMPOSE_DIR/vault/config/vault.hcl" <<EOL
listener "tcp" {
  address = "0.0.0.0:8200"
  tls_disable = 0
  tls_cert_file = "$CERT_DIR/vault-tls-certificate.pem"
  tls_key_file = "$CERT_DIR/vault-tls-private-key.pem"
}
storage "file" {
  path = "/servers/vault/data"
}
ui = true
EOL

# Update Docker Compose to use HTTPS
log "Updating Docker Compose to use HTTPS..."
cat > "$VAULT_COMPOSE_DIR/docker-compose.yml" <<EOL
services:
  vault:
    image: hashicorp/vault:latest
    container_name: vault
    restart: unless-stopped
    ports:
      - "8200:8200"
    environment:
      VAULT_DEV_ROOT_TOKEN_ID: root
    volumes:
      - ./vault:/vault
    command: server -config=/vault/config/vault.hcl
EOL


# Restart Vault with HTTPS
log "Restarting Vault with HTTPS..."
docker-compose -f "$VAULT_COMPOSE_DIR/docker-compose.yml" down
docker-compose -f "$VAULT_COMPOSE_DIR/docker-compose.yml" up -d

# Wait for Vault to be ready
log "Waiting for Vault to be ready..."
sleep 10

# Update VAULT_ADDR to use HTTPS
export VAULT_ADDR="https://$HOST_IP:8200"

# Add the CA certificate to the trusted store
log "Adding the CA certificate to the trusted store..."
update-ca-certificates

log "Vault CA and SSL configuration complete."