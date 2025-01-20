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
      VAULT_DEV_ROOT_TOKEN_ID: root
      VAULT_DEV_LISTEN_ADDRESS: 0.0.0.0:8200
    volumes:
      - vault_data:/vault/data
volumes:
  vault_data:
EOL

docker-compose -f "$VAULT_COMPOSE_DIR/docker-compose.yml" up -d

log "Vault setup complete."