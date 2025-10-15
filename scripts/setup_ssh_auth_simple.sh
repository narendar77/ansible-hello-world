#!/bin/bash

#############################################
# Simple SSH Authentication Setup Script
# Quick setup for Jenkins to Proxmox SSH
#############################################

PROXMOX_HOST="192.168.1.10"
PROXMOX_USER="root"
SSH_KEY_PATH="${HOME}/.ssh/id_rsa_proxmox"

echo "=========================================="
echo "SSH Key Setup for Proxmox"
echo "=========================================="
echo ""

# Create SSH directory
mkdir -p ~/.ssh
chmod 700 ~/.ssh

# Generate SSH key if it doesn't exist
if [ ! -f "${SSH_KEY_PATH}" ]; then
    echo "Generating SSH key..."
    ssh-keygen -t rsa -b 4096 -f "${SSH_KEY_PATH}" -N "" -C "jenkins-to-proxmox"
    echo "✓ SSH key generated: ${SSH_KEY_PATH}"
else
    echo "✓ SSH key already exists: ${SSH_KEY_PATH}"
fi

# Add to known_hosts
echo ""
echo "Adding Proxmox host to known_hosts..."
ssh-keyscan -H "${PROXMOX_HOST}" >> ~/.ssh/known_hosts 2>/dev/null
echo "✓ Host keys added"

# Copy key to Proxmox
echo ""
echo "Copying SSH key to Proxmox host..."
echo "You will be prompted for the Proxmox root password:"
ssh-copy-id -i "${SSH_KEY_PATH}.pub" "${PROXMOX_USER}@${PROXMOX_HOST}"

# Test connection
echo ""
echo "Testing SSH connection..."
if ssh -i "${SSH_KEY_PATH}" -o BatchMode=yes "${PROXMOX_USER}@${PROXMOX_HOST}" "echo 'Connection successful!'" 2>/dev/null; then
    echo "✓ SSH authentication working!"
    echo ""
    echo "=========================================="
    echo "Setup Complete!"
    echo "=========================================="
    echo ""
    echo "You can now connect using:"
    echo "  ssh -i ${SSH_KEY_PATH} ${PROXMOX_USER}@${PROXMOX_HOST}"
    echo ""
    echo "Public key location: ${SSH_KEY_PATH}.pub"
else
    echo "✗ SSH authentication test failed"
    echo "Please check the configuration"
    exit 1
fi
