# Hostname Configuration

## Overview

The Ansible role now automatically sets the hostname inside each VM to match the VM name in Proxmox.

## How It Works

After VMs are created and started, the playbook:
1. Waits for VMs to be running
2. Uses `qm guest exec` to run commands inside the VMs via QEMU Guest Agent
3. Sets the hostname using `hostnamectl set-hostname`
4. Updates `/etc/hostname` file

## Requirements

### QEMU Guest Agent Must Be Installed

The hostname configuration requires **QEMU Guest Agent** to be installed and running in your template VM.

#### Check if Guest Agent is Installed

SSH to your template or a running VM:
```bash
ssh root@VM_IP
systemctl status qemu-guest-agent
```

#### Install QEMU Guest Agent (if not installed)

**For Rocky Linux / RHEL / CentOS:**
```bash
yum install -y qemu-guest-agent
systemctl enable --now qemu-guest-agent
```

**For Ubuntu / Debian:**
```bash
apt-get update
apt-get install -y qemu-guest-agent
systemctl enable --now qemu-guest-agent
```

**Then update your template:**
```bash
# On Proxmox host
qm template 100  # Re-template after installing guest agent
```

## Configuration

### Enable/Disable Hostname Configuration

In `ansible/roles/proxmox_vm/defaults/main.yml`:

```yaml
configure_hostname: true  # Set to false to skip hostname configuration
```

### VM Hostnames

Each VM's hostname is defined in the `vms` list:

```yaml
vms:
  - hostname: "lxrancherlocalsbx01"  # This will be set inside the VM
    vmid: "201"
    # ...
```

## Verification

After the playbook runs, verify the hostname inside each VM:

```bash
# Get VM IP from Proxmox
ssh root@192.168.1.10 "qm guest cmd 201 network-get-interfaces"

# SSH to the VM and check hostname
ssh root@VM_IP
hostname
# Should output: lxrancherlocalsbx01
```

Or use Proxmox guest exec:
```bash
ssh root@192.168.1.10 "qm guest exec 201 -- hostname"
```

## Troubleshooting

### Error: "QEMU guest agent is not running"

**Cause:** Guest agent not installed or not running in the VM.

**Solution:**
1. SSH to the VM
2. Install guest agent (see above)
3. Start the service: `systemctl start qemu-guest-agent`
4. Re-run the playbook

### Hostname Not Set

**Check guest agent status:**
```bash
ssh root@192.168.1.10 "qm agent 201 ping"
```

Should return: `{"return":{}}`

**If it fails:**
- Guest agent not installed
- VM needs to be restarted after installing guest agent
- Template doesn't have guest agent

### Disable Hostname Configuration

If you don't want to configure hostnames, set in `defaults/main.yml`:

```yaml
configure_hostname: false
```

Or pass as extra var in Jenkinsfile:
```groovy
sh 'ansible-playbook ansible/create_vms.yml -i ansible/inventory -e "configure_hostname=false" -v'
```

## Manual Hostname Configuration

If QEMU guest agent is not available, you can set hostnames manually:

```bash
# SSH to each VM
ssh root@VM_IP

# Set hostname
hostnamectl set-hostname lxrancherlocalsbx01
echo "lxrancherlocalsbx01" > /etc/hostname

# Update /etc/hosts
echo "127.0.1.1 lxrancherlocalsbx01" >> /etc/hosts

# Verify
hostname
```

## Alternative: Cloud-Init

If your template supports cloud-init, you can enable it:

In `ansible/roles/proxmox_vm/defaults/main.yml`:
```yaml
use_cloud_init: true
```

Cloud-init will automatically set the hostname when the VM boots.

## What Gets Set

The playbook sets:
1. **System hostname**: `hostnamectl set-hostname <name>`
2. **/etc/hostname**: Contains the hostname
3. **Runtime hostname**: Immediately active

## Benefits

- ✅ Consistent naming between Proxmox and inside VMs
- ✅ Easy identification when SSH'd into VMs
- ✅ Proper hostname for logging and monitoring
- ✅ Automated - no manual configuration needed

## Example Output

```
TASK [proxmox_vm : Set hostname inside VMs using qm guest exec]
ok: [localhost] => (item={'hostname': 'lxrancherlocalsbx01', 'vmid': '201'})
ok: [localhost] => (item={'hostname': 'lxrancherlocalsbx02', 'vmid': '202'})
ok: [localhost] => (item={'hostname': 'lxrancherlocalsbx03', 'vmid': '203'})

TASK [proxmox_vm : Display hostname configuration status]
ok: [localhost] => (item=...) => {
    "msg": "Hostname 'lxrancherlocalsbx01' set for VM 201 - Status: Success"
}
ok: [localhost] => (item=...) => {
    "msg": "Hostname 'lxrancherlocalsbx02' set for VM 202 - Status: Success"
}
ok: [localhost] => (item=...) => {
    "msg": "Hostname 'lxrancherlocalsbx03' set for VM 203 - Status: Success"
}
```

## Summary

- **Automatic**: Hostnames set automatically during VM creation
- **Requires**: QEMU Guest Agent installed in template
- **Configurable**: Can be enabled/disabled via `configure_hostname` variable
- **Reliable**: Uses Proxmox's `qm guest exec` command
