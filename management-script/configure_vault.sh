#!/bin/bash

# Exit on any error
set -e

# Function to log messages
log() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $1"
}

log "Configuring Vault..."

# Enable SSH secrets engine in Vault
export VAULT_ADDR="https://$HOST_IP:8200"
export VAULT_TOKEN='root'

docker exec -e VAULT_ADDR=$VAULT_ADDR -e VAULT_TOKEN=$VAULT_TOKEN vault vault secrets enable -path=ssh-client-signer ssh
docker exec -e VAULT_ADDR=$VAULT_ADDR -e VAULT_TOKEN=$VAULT_TOKEN vault vault write ssh-client-signer/config/ca generate_signing_key=true

# Create SSH role
log "Creating SSH role..."
cat <<EOF > /tmp/ssh-role.json
{
  "algorithm_signer": "rsa-sha2-256",
  "allow_user_certificates": true,
  "allowed_users": "*",
  "allowed_extensions": "permit-pty,permit-port-forwarding",
  "default_extensions": {
    "permit-pty": {}
  },
  "key_type": "ca",
  "default_user": "bigboss",
  "ttl": "30m0s"
}
EOF

docker exec -i -e VAULT_ADDR=$VAULT_ADDR -e VAULT_TOKEN=$VAULT_TOKEN vault vault write ssh-client-signer/roles/my-role - < /tmp/ssh-role.json
rm /tmp/ssh-role.json

log "Vault configuration complete."