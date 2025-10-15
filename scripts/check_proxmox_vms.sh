#!/bin/bash

#############################################
# Check Proxmox VMs and Templates
#############################################

PROXMOX_HOST="192.168.1.10"
PROXMOX_USER="root"

echo "=========================================="
echo "Proxmox VMs and Templates Check"
echo "=========================================="
echo ""

echo "Connecting to Proxmox host: ${PROXMOX_HOST}"
echo ""

# List all VMs and templates
echo "All VMs and Templates:"
echo "----------------------------------------"
ssh ${PROXMOX_USER}@${PROXMOX_HOST} "qm list" | head -20

echo ""
echo "Templates only (marked with 'T'):"
echo "----------------------------------------"
ssh ${PROXMOX_USER}@${PROXMOX_HOST} "qm list" | grep -i template || echo "No templates found with 'template' in name"

echo ""
echo "Checking for VM ID 100 specifically:"
echo "----------------------------------------"
if ssh ${PROXMOX_USER}@${PROXMOX_HOST} "qm list" | grep -q "^\s*100\s"; then
    echo "✓ VM/Template with ID 100 exists:"
    ssh ${PROXMOX_USER}@${PROXMOX_HOST} "qm list" | grep "^\s*100\s"
    echo ""
    echo "Configuration for VM 100:"
    ssh ${PROXMOX_USER}@${PROXMOX_HOST} "qm config 100" | grep -E "(name|template)"
else
    echo "✗ VM/Template with ID 100 NOT found"
    echo ""
    echo "Available VM IDs:"
    ssh ${PROXMOX_USER}@${PROXMOX_HOST} "qm list" | awk 'NR>1 {print $1}' | head -10
fi

echo ""
echo "Checking for existing VMs with IDs 201, 202, 203:"
echo "----------------------------------------"
for vmid in 201 202 203; do
    if ssh ${PROXMOX_USER}@${PROXMOX_HOST} "qm list" | grep -q "^\s*${vmid}\s"; then
        echo "⚠ VM ${vmid} already exists:"
        ssh ${PROXMOX_USER}@${PROXMOX_HOST} "qm list" | grep "^\s*${vmid}\s"
    else
        echo "✓ VM ${vmid} does not exist (good - can be created)"
    fi
done

echo ""
echo "=========================================="
echo "Recommendation:"
echo "=========================================="
echo "1. Verify template ID 100 exists and is marked as template"
echo "2. If template has different ID, update ansible/roles/proxmox_vm/defaults/main.yml"
echo "3. Ensure VMs 201-203 don't already exist"
echo ""
