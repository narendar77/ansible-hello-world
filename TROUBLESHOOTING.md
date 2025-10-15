# Troubleshooting Guide

## Common Issues and Solutions

### 1. "Host key verification failed" Error

**Error Message:**
```
[ERROR]: Task failed: Failed to connect to the host via ssh: Host key verification failed.
```

**Root Cause:**
Ansible was trying to SSH to the Proxmox host, but the Proxmox API modules don't require SSH - they use HTTPS API calls.

**Solution Applied:**
1. ✅ Changed playbook to run on `localhost` instead of `proxmox` host
2. ✅ Added `connection: local` to playbook
3. ✅ Added `validate_certs: false` to all Proxmox API calls (for self-signed certs)
4. ✅ Added `delegate_to: localhost` to all tasks
5. ✅ Created `ansible.cfg` with proper SSH settings

**Files Modified:**
- `ansible/create_vms.yml` - Changed from `hosts: proxmox` to `hosts: localhost`
- `ansible/roles/proxmox_vm/tasks/main.yml` - Added `validate_certs: false` and `delegate_to: localhost`
- `ansible/ansible.cfg` - Created with `host_key_checking = False`

---

### 2. SSL Certificate Verification Errors

**Error Message:**
```
SSL certificate problem: self signed certificate
```

**Solution:**
Added `validate_certs: false` to all `proxmox_kvm` module calls. This is safe for internal Proxmox hosts.

---

### 3. Proxmox API Connection Issues

**Symptoms:**
- Cannot connect to Proxmox API
- Authentication failures
- Timeout errors

**Checklist:**

1. **Verify Proxmox is reachable:**
   ```bash
   ping 192.168.1.10
   curl -k https://192.168.1.10:8006/api2/json/version
   ```

2. **Check credentials:**
   - Username should be: `root@pam`
   - Password should be set in Jenkins credential: `proxmox-password`
   - Verify in Jenkins: Manage Jenkins → Manage Credentials

3. **Test API manually:**
   ```bash
   curl -k -d "username=root@pam&password=YOUR_PASSWORD" \
     https://192.168.1.10:8006/api2/json/access/ticket
   ```

4. **Check Proxmox firewall:**
   ```bash
   ssh root@192.168.1.10
   iptables -L | grep 8006
   ```

---

### 4. Template Not Found

**Error Message:**
```
VM template with ID 100 not found
```

**Solution:**

1. **List available templates on Proxmox:**
   ```bash
   ssh root@192.168.1.10 "qm list"
   ```

2. **Update template ID in defaults:**
   Edit `ansible/roles/proxmox_vm/defaults/main.yml`:
   ```yaml
   vm_template_id: "YOUR_TEMPLATE_ID"
   ```

---

### 5. VMID Already Exists

**Error Message:**
```
VM with ID 201 already exists
```

**Solutions:**

**Option A: Delete existing VMs**
```bash
ssh root@192.168.1.10
qm stop 201 && qm destroy 201
qm stop 202 && qm destroy 202
qm stop 203 && qm destroy 203
```

**Option B: Change VMIDs**
Edit `ansible/roles/proxmox_vm/defaults/main.yml`:
```yaml
vms:
  - hostname: "lxrancherlocalsbx01"
    vmid: "301"  # Changed from 201
```

---

### 6. Insufficient Storage

**Error Message:**
```
Not enough space on storage 'local-lvm'
```

**Solutions:**

1. **Check available storage:**
   ```bash
   ssh root@192.168.1.10 "pvesm status"
   ```

2. **Use different storage:**
   Edit `ansible/roles/proxmox_vm/defaults/main.yml`:
   ```yaml
   vm_storage: "local"  # or another storage name
   ```

---

### 7. Python Dependencies Missing

**Error Message:**
```
No module named 'proxmoxer'
```

**Solution:**
The Jenkinsfile already handles this in the "Install Dependencies" stage:
```groovy
sh 'pip install proxmoxer requests'
```

If running manually:
```bash
pip install -r requirements.txt
```

---

### 8. Ansible Collection Not Found

**Error Message:**
```
couldn't resolve module/action 'community.general.proxmox_kvm'
```

**Solution:**
The Jenkinsfile already handles this:
```groovy
sh 'ansible-galaxy collection install -r ansible/requirements.yml'
```

If running manually:
```bash
ansible-galaxy collection install -r ansible/requirements.yml
```

---

## How Proxmox API Works

**Important Understanding:**

The `community.general.proxmox_kvm` module:
- ✅ Uses HTTPS API (port 8006)
- ✅ Does NOT require SSH to Proxmox
- ✅ Runs from Jenkins/localhost
- ✅ Only needs API credentials (username/password)

**Architecture:**
```
Jenkins Container (localhost)
    ↓
    | HTTPS API Call (port 8006)
    ↓
Proxmox Host (192.168.1.10)
    ↓
    | Creates VMs
    ↓
VM 201, 202, 203
```

**This is why:**
- Playbook runs on `localhost`
- No SSH keys needed for VM creation
- Only API password required

---

## Verification Commands

### Check if VMs were created:
```bash
ssh root@192.168.1.10 "qm list | grep lxrancher"
```

### Check VM status:
```bash
ssh root@192.168.1.10 "qm status 201"
```

### View VM configuration:
```bash
ssh root@192.168.1.10 "qm config 201"
```

### Check Proxmox logs:
```bash
ssh root@192.168.1.10 "tail -f /var/log/pve/tasks/active"
```

---

## Jenkins Pipeline Debug

### Enable verbose Ansible output:
Edit `Jenkinsfile`, change:
```groovy
sh 'ansible-playbook ansible/create_vms.yml -i ansible/inventory -v'
```
to:
```groovy
sh 'ansible-playbook ansible/create_vms.yml -i ansible/inventory -vvv'
```

### Test playbook manually in Jenkins:
```bash
# SSH into Jenkins host
docker exec -it <jenkins-container> bash

# Run playbook manually
cd /var/lib/jenkins/workspace/VM-Creation
export PROXMOX_PASSWORD='your-password'
ansible-playbook ansible/create_vms.yml -i ansible/inventory -vvv
```

---

## Quick Test Script

Save as `test_proxmox_api.sh`:
```bash
#!/bin/bash
PROXMOX_HOST="192.168.1.10"
PROXMOX_USER="root@pam"
PROXMOX_PASS="your-password"

# Test API connectivity
echo "Testing Proxmox API..."
curl -k -d "username=${PROXMOX_USER}&password=${PROXMOX_PASS}" \
  https://${PROXMOX_HOST}:8006/api2/json/access/ticket

# List VMs
echo -e "\n\nListing VMs..."
ssh root@${PROXMOX_HOST} "qm list"
```

---

## Getting Help

1. **Check Jenkins Console Output** - Full error messages
2. **Check Proxmox Task Log** - Web UI → Datacenter → Tasks
3. **Enable Ansible Debug** - Use `-vvv` flag
4. **Check this guide** - Common issues listed above

## Configuration Files Reference

- `ansible/ansible.cfg` - Ansible configuration
- `ansible/create_vms.yml` - Main playbook
- `ansible/roles/proxmox_vm/defaults/main.yml` - VM specifications
- `ansible/roles/proxmox_vm/tasks/main.yml` - Proxmox API tasks
- `Jenkinsfile` - Jenkins pipeline definition
