#!/bin/bash

#############################################
# Local Test Script for Proxmox VM Creation
# Run this to test without Jenkins
#############################################

set -e

PROXMOX_PASSWORD="reddy007"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$( cd "$SCRIPT_DIR/.." && pwd )"
ANSIBLE_DIR="$PROJECT_DIR/ansible"

echo "=========================================="
echo "Local Proxmox VM Creation Test"
echo "=========================================="
echo ""
echo "Project Directory: $PROJECT_DIR"
echo "Ansible Directory: $ANSIBLE_DIR"
echo ""

# Check if we're in the right directory
if [ ! -f "$ANSIBLE_DIR/create_vms.yml" ]; then
    echo "ERROR: Cannot find ansible/create_vms.yml"
    echo "Please run this script from the project root or scripts directory"
    exit 1
fi

# Check dependencies
echo "Checking dependencies..."
if ! command -v ansible-playbook &> /dev/null; then
    echo "ERROR: ansible-playbook not found"
    echo "Install with: pip install ansible"
    exit 1
fi

if ! python3 -c "import proxmoxer" 2>/dev/null; then
    echo "Installing proxmoxer..."
    pip install proxmoxer requests
fi

if ! ansible-galaxy collection list | grep -q "community.general" 2>/dev/null; then
    echo "Installing Ansible collections..."
    ansible-galaxy collection install -r "$ANSIBLE_DIR/requirements.yml"
fi

echo "✓ All dependencies installed"
echo ""

# Export password
export PROXMOX_PASSWORD="$PROXMOX_PASSWORD"

# Run playbook
echo "=========================================="
echo "Running Ansible Playbook"
echo "=========================================="
echo ""

cd "$ANSIBLE_DIR"
ansible-playbook create_vms.yml -i inventory -v

echo ""
echo "=========================================="
echo "Playbook Execution Complete"
echo "=========================================="
echo ""
echo "Verify VMs created:"
echo "  ssh root@192.168.1.10 'qm list | grep lxrancher'"
echo ""
