#!/bin/bash

# Exit on any error
set -e

# Function to log messages
log() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $1"
}

log "Setting up Portainer with Docker Compose..."

# Create a directory for Docker Compose configurations
COMPOSE_DIR="$HOME/docker-compose-configs"
mkdir -p "$COMPOSE_DIR"

# Portainer Docker Compose
PORTAINER_COMPOSE_DIR="$COMPOSE_DIR/portainer"
mkdir -p "$PORTAINER_COMPOSE_DIR"

cat > "$PORTAINER_COMPOSE_DIR/docker-compose.yml" <<EOL
services:
  portainer:
    image: portainer/portainer-ce:latest
    container_name: portainer
    restart: unless-stopped
    ports:
      - "9000:9000"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - portainer_data:/data
volumes:
  portainer_data:
EOL

docker-compose -f "$PORTAINER_COMPOSE_DIR/docker-compose.yml" up -d

log "Portainer setup complete."