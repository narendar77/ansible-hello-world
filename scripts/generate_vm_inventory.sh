#!/bin/bash

#############################################
# Generate Ansible Inventory for Created VMs
# Gets IP addresses from Proxmox and creates inventory file
#############################################

PROXMOX_HOST="192.168.1.10"
PROXMOX_USER="root"
OUTPUT_FILE="../ansible/inventory_vms"

# VM configuration (VMID:HOSTNAME)
declare -A VMS=(
    ["201"]="lxrancherlocalsbx01"
    ["202"]="lxrancherlocalsbx02"
    ["203"]="lxrancherlocalsbx03"
)

echo "=========================================="
echo "Generating VM Inventory"
echo "=========================================="
echo ""

# Create inventory file header
cat > "$OUTPUT_FILE" << 'EOF'
[created_vms]
# Auto-generated inventory for created VMs
# Generated on: $(date)

EOF

echo "Fetching VM IP addresses from Proxmox..."
echo ""

# Get IP for each VM
for vmid in "${!VMS[@]}"; do
    hostname="${VMS[$vmid]}"
    echo "Checking VM $vmid ($hostname)..."
    
    # Try to get IP from qm guest cmd
    ip_address=$(ssh ${PROXMOX_USER}@${PROXMOX_HOST} "qm guest cmd $vmid network-get-interfaces 2>/dev/null" | \
                 grep -oP '(?<=\"ip-address\":\")[^\"]*' | \
                 grep -v "127.0.0.1" | \
                 grep -v "::" | \
                 head -1)
    
    if [ -z "$ip_address" ]; then
        # Fallback: try to get from qm config
        echo "  ⚠ Could not get IP via guest agent, checking DHCP leases..."
        ip_address="# UNKNOWN - Please add manually"
    else
        echo "  ✓ Found IP: $ip_address"
    fi
    
    # Add to inventory
    if [[ "$ip_address" == "#"* ]]; then
        echo "$ip_address for VM $vmid ($hostname)" >> "$OUTPUT_FILE"
        echo "# $ip_address target_hostname=$hostname ansible_host=REPLACE_WITH_IP" >> "$OUTPUT_FILE"
    else
        echo "$ip_address target_hostname=$hostname" >> "$OUTPUT_FILE"
    fi
done

# Add group vars
cat >> "$OUTPUT_FILE" << 'EOF'

[created_vms:vars]
ansible_user=root
ansible_ssh_common_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
# Uncomment one of the following authentication methods:
# ansible_password=your_vm_password
# ansible_ssh_private_key_file=~/.ssh/id_rsa_proxmox
EOF

echo ""
echo "=========================================="
echo "Inventory file generated: $OUTPUT_FILE"
echo "=========================================="
echo ""
echo "Review and update the file if needed, then run:"
echo "  cd ansible"
echo "  ansible-playbook configure_hostnames.yml -i inventory_vms"
echo ""
