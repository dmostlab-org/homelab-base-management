#!/bin/bash

# Function to log messages
log() {
  echo "[INFO] $1"
}

# Stop and remove Vault container
log "Stopping and removing Vault container..."
docker-compose -f "$HOME/docker-compose-configs/vault/docker-compose.yml" down
docker rm -f vault

# Remove Docker Compose configurations
log "Removing Docker Compose configurations..."
COMPOSE_DIR="$HOME/docker-compose-configs"
rm -rf "$COMPOSE_DIR"

# Remove Docker Compose
log "Removing Docker Compose..."
rm -f /usr/local/bin/docker-compose

# Remove Docker
log "Removing Docker..."
apt-get purge -y docker-ce docker-ce-cli containerd.io
apt-get autoremove -y --purge
rm -rf /var/lib/docker
rm -rf /var/lib/containerd

# Remove Terraform
log "Removing Terraform..."
apt-get remove -y terraform
rm -f /etc/apt/sources.list.d/hashicorp.list
rm -f /usr/share/keyrings/hashicorp-archive-keyring.gpg
apt-get update

# Remove Ansible
log "Removing Ansible..."
apt-get remove -y ansible
apt-get autoremove -y

# Remove any remaining files or directories created by the initial script
log "Removing remaining files and directories..."
rm -rf /tmp/ssh-role.json

log "Cleanup complete."