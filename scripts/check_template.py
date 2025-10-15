#!/usr/bin/env python3
"""
Check Proxmox Template and VM IDs
"""

import sys
try:
    from proxmoxer import ProxmoxAPI
    import requests
    requests.packages.urllib3.disable_warnings()
except ImportError:
    print("ERROR: Install required packages: pip install proxmoxer requests")
    sys.exit(1)

PROXMOX_HOST = "192.168.1.10"
PROXMOX_USER = "root@pam"
PROXMOX_PASSWORD = "reddy007"
PROXMOX_NODE = "pve"
TEMPLATE_ID = 100
TARGET_VMIDS = [201, 202, 203]

print("=" * 60)
print("Proxmox Template and VM Check")
print("=" * 60)
print()

try:
    # Connect to Proxmox
    print(f"Connecting to {PROXMOX_HOST}...")
    proxmox = ProxmoxAPI(
        PROXMOX_HOST,
        user=PROXMOX_USER,
        password=PROXMOX_PASSWORD,
        verify_ssl=False
    )
    print("✓ Connected successfully")
    print()
    
    # Get all VMs
    print(f"Fetching VMs from node '{PROXMOX_NODE}'...")
    vms = proxmox.nodes(PROXMOX_NODE).qemu.get()
    print(f"✓ Found {len(vms)} VMs/Templates")
    print()
    
    # Check for template
    print("=" * 60)
    print(f"Checking for Template ID {TEMPLATE_ID}")
    print("=" * 60)
    
    template = None
    for vm in vms:
        if vm['vmid'] == TEMPLATE_ID:
            template = vm
            break
    
    if template:
        print(f"✓ VM/Template {TEMPLATE_ID} exists")
        print(f"  Name: {template.get('name', 'N/A')}")
        print(f"  Status: {template.get('status', 'N/A')}")
        print(f"  Is Template: {template.get('template', 0) == 1}")
        
        if template.get('template', 0) != 1:
            print()
            print("⚠ WARNING: VM 100 exists but is NOT marked as a template!")
            print("  You need to convert it to a template or use a different ID")
            print()
            print("  To convert to template:")
            print(f"    ssh root@{PROXMOX_HOST} 'qm template {TEMPLATE_ID}'")
    else:
        print(f"✗ Template/VM with ID {TEMPLATE_ID} NOT FOUND")
        print()
        print("Available VMs/Templates:")
        for vm in sorted(vms, key=lambda x: x['vmid'])[:10]:
            is_template = "📋 TEMPLATE" if vm.get('template', 0) == 1 else "🖥️  VM"
            print(f"  {is_template} - ID: {vm['vmid']:3d} - Name: {vm.get('name', 'N/A')}")
        
        print()
        print("ACTION REQUIRED:")
        print(f"  Update ansible/roles/proxmox_vm/defaults/main.yml")
        print(f"  Change 'vm_template_id' to one of the template IDs above")
    
    print()
    
    # Check target VMIDs
    print("=" * 60)
    print("Checking Target VM IDs (201, 202, 203)")
    print("=" * 60)
    
    conflicts = []
    for target_id in TARGET_VMIDS:
        exists = any(vm['vmid'] == target_id for vm in vms)
        if exists:
            vm_info = next(vm for vm in vms if vm['vmid'] == target_id)
            print(f"⚠ VM {target_id} already exists: {vm_info.get('name', 'N/A')}")
            conflicts.append(target_id)
        else:
            print(f"✓ VM {target_id} available (can be created)")
    
    if conflicts:
        print()
        print("ACTION REQUIRED:")
        print("  Delete existing VMs or change target VMIDs")
        print()
        print("  To delete:")
        for vmid in conflicts:
            print(f"    ssh root@{PROXMOX_HOST} 'qm stop {vmid} && qm destroy {vmid}'")
        print()
        print("  Or update ansible/roles/proxmox_vm/defaults/main.yml")
        print("  to use different VMIDs (e.g., 301, 302, 303)")
    
    print()
    print("=" * 60)
    print("Summary")
    print("=" * 60)
    
    if template and template.get('template', 0) == 1 and not conflicts:
        print("✓ All checks passed! Ready to create VMs.")
    else:
        print("⚠ Issues found. Please resolve before proceeding:")
        if not template:
            print("  - Template 100 not found")
        elif template.get('template', 0) != 1:
            print("  - VM 100 is not a template")
        if conflicts:
            print(f"  - VMIDs already in use: {conflicts}")
    
    print()

except Exception as e:
    print(f"✗ Error: {e}")
    sys.exit(1)
