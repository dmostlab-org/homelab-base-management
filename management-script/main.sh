#!/bin/bash

# Exit on any error
set -e

# Function to log messages
log() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $1"
}

log "Starting management machine bootstrap..."

# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then
    log "Please run as root"
    exit 1
fi

# Collect variables
read -p "Enter domain for CA common name (used for generating CA certificates): " DOMAIN_NAME
if [ -z "$DOMAIN_NAME" ]; then
    log "Domain name is required"
    exit 1
fi

# Extract the domain without the TLD
DOMAIN=$(echo "$DOMAIN_NAME" | awk -F. '{OFS="."; NF--; print}')

read -p "Enter the hostname for the SSL certificate (used for Vault's HTTPS configuration): " HOSTNAME
if [ -z "$HOSTNAME" ]; then
    log "Hostname is required"
    exit 1
fi

HOST_IP=$(hostname -I | awk '{print $1}')
log "Detected host IP: $HOST_IP"


# Make scripts executable
chmod +x install_dependencies.sh setup_vault.sh setup_portainer.sh configure_vault_ca.sh configure_vault.sh


# Export variables for use in other scripts
export DOMAIN_NAME
export HOSTNAME
export HOST_IP
export DOMAIN


# Run the scripts in order
./install_dependencies.sh
./setup_portainer.sh
./setup_vault.sh
./configure_vault_ca.sh
./configure_vault.sh

log "Bootstrap complete. Docker Compose configurations are stored in $HOME/docker-compose-configs."
log "Please log out and log back in to ensure Docker group permissions are applied."