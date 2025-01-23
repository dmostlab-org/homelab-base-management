#!/bin/bash

# Exit on any error
set -e

# Function to log messages
log() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $1"
}

log "Setting up HashiCorp Vault with Docker Compose..."

# Create a directory for Docker Compose configurations
COMPOSE_DIR="$HOME/docker-compose-configs"
mkdir -p "$COMPOSE_DIR"

# HashiCorp Vault Docker Compose
VAULT_COMPOSE_DIR="$COMPOSE_DIR/vault"
mkdir -p "$VAULT_COMPOSE_DIR"

cat > "$VAULT_COMPOSE_DIR/docker-compose.yml" <<EOL
services:
  vault:
    image: hashicorp/vault:latest
    container_name: vault
    restart: unless-stopped
    ports:
      - "8200:8200"
    environment:
      VAULT_ADDR: http://0.0.0.0:8200
    volumes:
      - vault_data:/vault/data
      - $VAULT_COMPOSE_DIR/config:/vault/config
    command: "server -config=/vault/config/config.hcl"
volumes:
  vault_data:
EOL

# Create Vault configuration directory and file
mkdir -p "$VAULT_COMPOSE_DIR/config"

cat > "$VAULT_COMPOSE_DIR/config/config.hcl" <<EOL
listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = 1  # Replace this with TLS settings for production
}
storage "file" {
  path = "/vault/data"
}

disable_mlock = true
ui = true
EOL

log "Starting Vault in production mode..."
docker-compose -f "$VAULT_COMPOSE_DIR/docker-compose.yml" up -d

# Initialize Vault and store unseal keys and root token securely
log "Initializing Vault..."
docker exec -it vault vault operator init -key-shares=3 -key-threshold=2 > "$VAULT_COMPOSE_DIR/init-output.txt"

# Extract unseal keys and root token
UNSEAL_KEYS=($(grep 'Unseal Key' "$VAULT_COMPOSE_DIR/init-output.txt" | awk '{print $4}'))
VAULT_TOKEN=$(grep 'Initial Root Token' "$VAULT_COMPOSE_DIR/init-output.txt" | awk '{print $4}')

export VAULT_TOKEN

# Unseal Vault
log "Unsealing Vault..."
docker exec -it vault vault operator unseal "${UNSEAL_KEYS[0]}"
docker exec -it vault vault operator unseal "${UNSEAL_KEYS[1]}"

# Log root token (for demonstration; remove this in production)
log "Root Token: $VAULT_TOKEN"

# Clean up unseal keys and root token
shred -u "$VAULT_COMPOSE_DIR/init-output.txt"


log "Vault setup complete."