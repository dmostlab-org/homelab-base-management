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

docker exec -e VAULT_ADDR=$VAULT_ADDR -e VAULT_TOKEN=$VAULT_TOKEN vault vault secrets enable pki
docker exec -e VAULT_ADDR=$VAULT_ADDR -e VAULT_TOKEN=$VAULT_TOKEN vault vault secrets tune -max-lease-ttl=8760h pki
docker exec -e VAULT_ADDR=$VAULT_ADDR -e VAULT_TOKEN=$VAULT_TOKEN vault vault write pki/root/generate/internal common_name="$DOMAIN_NAME" ttl=8760h key_type="rsa" key_bits="2048"
docker exec -e VAULT_ADDR=$VAULT_ADDR -e VAULT_TOKEN=$VAULT_TOKEN vault vault write pki/config/urls issuing_certificates="$VAULT_ADDR/v1/pki/ca" crl_distribution_points="$VAULT_ADDR/v1/pki/crl"

# Generate a certificate for Vault
log "Generating a certificate for Vault..."
docker exec -e VAULT_ADDR=$VAULT_ADDR -e VAULT_TOKEN=$VAULT_TOKEN vault vault write pki/issue/vault-dot-com common_name="$HOSTNAME" alt_names="$HOST_IP" ttl="8760h" > /tmp/vault-cert.json

# Extract the certificate and key
VAULT_CERT=$(jq -r .data.certificate /tmp/vault-cert.json)
VAULT_KEY=$(jq -r .data.private_key /tmp/vault-cert.json)
VAULT_CA=$(jq -r .data.issuing_ca /tmp/vault-cert.json)

# Save the certificate and key to files
VAULT_COMPOSE_DIR="$HOME/docker-compose-configs/vault"
echo "$VAULT_CERT" > "$VAULT_COMPOSE_DIR/vault/vault.crt"
echo "$VAULT_KEY" > "$VAULT_COMPOSE_DIR/vault/vault.key"
echo "$VAULT_CA" > /usr/local/share/ca-certificates/vault-ca.crt

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

# Create Vault configuration file
mkdir -p "$VAULT_COMPOSE_DIR/vault/config"
cat > "$VAULT_COMPOSE_DIR/vault/config/vault.hcl" <<EOL
listener "tcp" {
  address = "0.0.0.0:8200"
  tls_cert_file = "/vault/vault.crt"
  tls_key_file = "/vault/vault.key"
}
storage "file" {
  path = "/vault/data"
}
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