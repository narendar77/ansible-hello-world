#!/bin/bash

#############################################
# Check Proxmox Node Name
#############################################

PROXMOX_HOST="192.168.1.10"
PROXMOX_USER="root"

echo "=========================================="
echo "Proxmox Node Name Check"
echo "=========================================="
echo ""

echo "Getting node name from Proxmox..."
echo ""

# Method 1: Check hostname
echo "1. Hostname:"
ssh ${PROXMOX_USER}@${PROXMOX_HOST} "hostname"

echo ""
echo "2. Node name from pvesh:"
ssh ${PROXMOX_USER}@${PROXMOX_HOST} "pvesh get /nodes --output-format=json" | grep -o '"node":"[^"]*"' | cut -d'"' -f4

echo ""
echo "3. All nodes in cluster:"
ssh ${PROXMOX_USER}@${PROXMOX_HOST} "pvesh get /nodes"

echo ""
echo "4. Node from qm list:"
ssh ${PROXMOX_USER}@${PROXMOX_HOST} "qm config 100" | grep -i node || echo "No node info in VM config"

echo ""
echo "=========================================="
echo "Update ansible/roles/proxmox_vm/defaults/main.yml"
echo "Set proxmox_node to the correct value above"
echo "=========================================="
