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

# Make scripts executable
chmod +x install_dependencies.sh setup_vault.sh setup_portainer.sh configure_vault_ca.sh configure_vault.sh
# Run the scripts in order
./install_dependencies.sh
./setup_vault.sh
./setup_portainer.sh
./configure_vault_ca.sh
./configure_vault.sh

log "Bootstrap complete. Docker Compose configurations are stored in $HOME/docker-compose-configs."
log "Please log out and log back in to ensure Docker group permissions are applied."