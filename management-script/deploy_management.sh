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

# Prompt for domain name if not provided
if [ -z "$DOMAIN_NAME" ]; then
    read -p "Enter domain for CA common name: " DOMAIN_NAME
fi

if [ -z "$DOMAIN_NAME" ]; then
    log "Domain name is required"
    exit 1
fi

# Update system and install prerequisites
log "Updating system packages..."
apt-get update && apt-get upgrade -y
apt-get install -y \
    curl \
    wget \
    software-properties-common \
    apt-transport-https \
    gnupg \
    ca-certificates

# Install Ansible
log "Installing Ansible..."
apt-add-repository -y ppa:ansible/ansible
apt-get update
apt-get install -y ansible

# Install Docker
log "Installing Docker..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io
usermod -aG docker $SUDO_USER

# Install Docker Compose
log "Installing Docker Compose..."
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
docker-compose --version

# Install Terraform
log "Installing Terraform..."
wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | tee /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list
apt-get update
apt-get install -y terraform

# Create a directory for Docker Compose configurations
COMPOSE_DIR="$HOME/docker-compose-configs"
mkdir -p "$COMPOSE_DIR"

# HashiCorp Vault Docker Compose
log "Setting up HashiCorp Vault with Docker Compose..."
VAULT_COMPOSE_DIR="$COMPOSE_DIR/vault"
mkdir -p "$VAULT_COMPOSE_DIR"

cat > "$VAULT_COMPOSE_DIR/docker-compose.yml" <<EOL
version: '3.8'
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

# Portainer Docker Compose
log "Setting up Portainer with Docker Compose..."
PORTAINER_COMPOSE_DIR="$COMPOSE_DIR/portainer"
mkdir -p "$PORTAINER_COMPOSE_DIR"

cat > "$PORTAINER_COMPOSE_DIR/docker-compose.yml" <<EOL
version: '3.8'
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

# Wait for Vault to be ready
log "Waiting for Vault to be ready..."
sleep 10

# Enable PKI and SSH secrets engines in Vault
log "Enabling PKI and SSH secrets engines in Vault..."
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='root'

docker exec -e VAULT_ADDR=$VAULT_ADDR -e VAULT_TOKEN=$VAULT_TOKEN vault vault secrets enable -path=ssh-client-signer ssh
docker exec -e VAULT_ADDR=$VAULT_ADDR -e VAULT_TOKEN=$VAULT_TOKEN vault vault write ssh-client-signer/config/ca generate_signing_key=true
docker exec -e VAULT_ADDR=$VAULT_ADDR -e VAULT_TOKEN=$VAULT_TOKEN vault vault write ssh-client-signer/roles/my-role -<<"EOH"


log "Bootstrap complete. Docker Compose configurations are stored in $COMPOSE_DIR."
log "Please log out and log back in to ensure Docker group permissions are applied."
