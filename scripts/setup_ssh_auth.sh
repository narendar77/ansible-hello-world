#!/bin/bash

#############################################
# SSH Authentication Setup Script
# Purpose: Configure SSH key authentication
#          between Jenkins host and Proxmox
#############################################

set -e  # Exit on error

# Configuration
JENKINS_HOST="192.168.1.141"
PROXMOX_HOST="192.168.1.10"
PROXMOX_USER="root"
SSH_KEY_TYPE="rsa"
SSH_KEY_BITS="4096"
SSH_KEY_NAME="id_${SSH_KEY_TYPE}_proxmox"
SSH_DIR="${HOME}/.ssh"
SSH_KEY_PATH="${SSH_DIR}/${SSH_KEY_NAME}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Functions
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo ""
    echo "=========================================="
    echo "$1"
    echo "=========================================="
    echo ""
}

# Check if running on correct host
check_host() {
    print_header "Checking Current Host"
    CURRENT_IP=$(hostname -I | awk '{print $1}')
    print_info "Current host IP: ${CURRENT_IP}"
    
    if [[ "${CURRENT_IP}" != "${JENKINS_HOST}" ]]; then
        print_warning "This script should be run from Jenkins host (${JENKINS_HOST})"
        print_warning "Current host: ${CURRENT_IP}"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# Create SSH directory if it doesn't exist
setup_ssh_directory() {
    print_header "Setting Up SSH Directory"
    
    if [ ! -d "${SSH_DIR}" ]; then
        print_info "Creating SSH directory: ${SSH_DIR}"
        mkdir -p "${SSH_DIR}"
        chmod 700 "${SSH_DIR}"
    else
        print_info "SSH directory already exists: ${SSH_DIR}"
    fi
}

# Generate SSH key pair
generate_ssh_key() {
    print_header "Generating SSH Key Pair"
    
    if [ -f "${SSH_KEY_PATH}" ]; then
        print_warning "SSH key already exists: ${SSH_KEY_PATH}"
        read -p "Do you want to overwrite it? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Using existing SSH key"
            return 0
        fi
        print_info "Backing up existing key to ${SSH_KEY_PATH}.backup"
        cp "${SSH_KEY_PATH}" "${SSH_KEY_PATH}.backup"
        cp "${SSH_KEY_PATH}.pub" "${SSH_KEY_PATH}.pub.backup"
    fi
    
    print_info "Generating ${SSH_KEY_TYPE} key (${SSH_KEY_BITS} bits)..."
    ssh-keygen -t ${SSH_KEY_TYPE} -b ${SSH_KEY_BITS} -f "${SSH_KEY_PATH}" -N "" -C "jenkins@${JENKINS_HOST}"
    
    if [ $? -eq 0 ]; then
        print_info "SSH key pair generated successfully"
        print_info "Private key: ${SSH_KEY_PATH}"
        print_info "Public key: ${SSH_KEY_PATH}.pub"
    else
        print_error "Failed to generate SSH key pair"
        exit 1
    fi
}

# Test SSH connectivity
test_ssh_connection() {
    print_header "Testing SSH Connection to Proxmox"
    
    print_info "Attempting to connect to ${PROXMOX_USER}@${PROXMOX_HOST}..."
    
    if ssh -o BatchMode=yes -o ConnectTimeout=5 "${PROXMOX_USER}@${PROXMOX_HOST}" "echo 'SSH connection successful'" 2>/dev/null; then
        print_info "SSH connection successful!"
        return 0
    else
        print_warning "SSH connection failed (expected if key not yet copied)"
        return 1
    fi
}

# Copy SSH key to Proxmox host
copy_ssh_key() {
    print_header "Copying SSH Key to Proxmox Host"
    
    print_info "You will be prompted for the Proxmox root password"
    print_info "Target: ${PROXMOX_USER}@${PROXMOX_HOST}"
    echo ""
    
    ssh-copy-id -i "${SSH_KEY_PATH}.pub" "${PROXMOX_USER}@${PROXMOX_HOST}"
    
    if [ $? -eq 0 ]; then
        print_info "SSH key copied successfully"
    else
        print_error "Failed to copy SSH key"
        exit 1
    fi
}

# Add Proxmox host to known_hosts
add_to_known_hosts() {
    print_header "Adding Proxmox Host to Known Hosts"
    
    print_info "Scanning SSH host keys from ${PROXMOX_HOST}..."
    ssh-keyscan -H "${PROXMOX_HOST}" >> "${SSH_DIR}/known_hosts" 2>/dev/null
    
    if [ $? -eq 0 ]; then
        print_info "Host keys added to known_hosts"
    else
        print_warning "Failed to add host keys (may need to do manually)"
    fi
}

# Configure SSH config file
configure_ssh_config() {
    print_header "Configuring SSH Config"
    
    SSH_CONFIG="${SSH_DIR}/config"
    
    # Check if entry already exists
    if grep -q "Host proxmox" "${SSH_CONFIG}" 2>/dev/null; then
        print_warning "SSH config entry for 'proxmox' already exists"
        return 0
    fi
    
    print_info "Adding Proxmox host configuration to ${SSH_CONFIG}"
    
    cat >> "${SSH_CONFIG}" << EOF

# Proxmox Host Configuration
Host proxmox
    HostName ${PROXMOX_HOST}
    User ${PROXMOX_USER}
    IdentityFile ${SSH_KEY_PATH}
    StrictHostKeyChecking no
    UserKnownHostsFile ${SSH_DIR}/known_hosts

EOF
    
    chmod 600 "${SSH_CONFIG}"
    print_info "SSH config updated"
    print_info "You can now connect using: ssh proxmox"
}

# Verify authentication
verify_authentication() {
    print_header "Verifying SSH Authentication"
    
    print_info "Testing passwordless SSH connection..."
    
    if ssh -o BatchMode=yes -o ConnectTimeout=5 "${PROXMOX_USER}@${PROXMOX_HOST}" "hostname && uptime" 2>/dev/null; then
        print_info "✓ Passwordless SSH authentication working!"
        echo ""
        print_info "Connection details:"
        ssh "${PROXMOX_USER}@${PROXMOX_HOST}" "echo '  Hostname: \$(hostname)' && echo '  Proxmox Version: \$(pveversion)' && echo '  Uptime: \$(uptime -p)'"
        return 0
    else
        print_error "✗ Passwordless SSH authentication failed"
        print_error "Please check the configuration and try again"
        return 1
    fi
}

# Display summary
display_summary() {
    print_header "Setup Summary"
    
    echo "SSH Key Details:"
    echo "  Private Key: ${SSH_KEY_PATH}"
    echo "  Public Key:  ${SSH_KEY_PATH}.pub"
    echo ""
    echo "Connection Details:"
    echo "  From: ${JENKINS_HOST} (Jenkins)"
    echo "  To:   ${PROXMOX_HOST} (Proxmox)"
    echo "  User: ${PROXMOX_USER}"
    echo ""
    echo "Usage:"
    echo "  Direct:    ssh ${PROXMOX_USER}@${PROXMOX_HOST}"
    echo "  Alias:     ssh proxmox"
    echo "  With key:  ssh -i ${SSH_KEY_PATH} ${PROXMOX_USER}@${PROXMOX_HOST}"
    echo ""
    
    print_info "Public key content (for manual setup if needed):"
    echo "----------------------------------------"
    cat "${SSH_KEY_PATH}.pub"
    echo "----------------------------------------"
}

# Main execution
main() {
    print_header "SSH Authentication Setup Script"
    echo "Jenkins Host: ${JENKINS_HOST}"
    echo "Proxmox Host: ${PROXMOX_HOST}"
    echo ""
    
    # Check if ssh-keygen is available
    if ! command -v ssh-keygen &> /dev/null; then
        print_error "ssh-keygen not found. Please install OpenSSH client."
        exit 1
    fi
    
    # Check if ssh-copy-id is available
    if ! command -v ssh-copy-id &> /dev/null; then
        print_error "ssh-copy-id not found. Please install OpenSSH client."
        exit 1
    fi
    
    # Execute setup steps
    check_host
    setup_ssh_directory
    generate_ssh_key
    add_to_known_hosts
    
    # Test if already configured
    if test_ssh_connection; then
        print_info "SSH authentication already configured!"
        configure_ssh_config
        display_summary
        exit 0
    fi
    
    # Copy key and verify
    copy_ssh_key
    configure_ssh_config
    
    echo ""
    sleep 2
    
    if verify_authentication; then
        echo ""
        display_summary
        print_info "✓ SSH authentication setup completed successfully!"
        exit 0
    else
        print_error "✗ Setup completed but verification failed"
        print_error "Please check the configuration manually"
        exit 1
    fi
}

# Run main function
main
