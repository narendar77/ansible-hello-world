#!/bin/bash

#############################################
# Check Proxmox Storage
#############################################

PROXMOX_HOST="192.168.1.10"
PROXMOX_USER="root"

echo "=========================================="
echo "Proxmox Storage Check"
echo "=========================================="
echo ""

echo "Available Storage:"
echo "----------------------------------------"
ssh ${PROXMOX_USER}@${PROXMOX_HOST} "pvesm status"

echo ""
echo "Template 100 Storage Location:"
echo "----------------------------------------"
ssh ${PROXMOX_USER}@${PROXMOX_HOST} "qm config 100 | grep -E '(scsi|ide|virtio|sata)'"

echo ""
echo "Checking 'local-lvm' storage:"
echo "----------------------------------------"
if ssh ${PROXMOX_USER}@${PROXMOX_HOST} "pvesm status" | grep -q "local-lvm"; then
    echo "✓ local-lvm storage exists"
    ssh ${PROXMOX_USER}@${PROXMOX_HOST} "pvesm status" | grep "local-lvm"
else
    echo "✗ local-lvm storage not found"
    echo ""
    echo "Available storage:"
    ssh ${PROXMOX_USER}@${PROXMOX_HOST} "pvesm status | awk 'NR>1 {print \$1}'"
fi

echo ""
