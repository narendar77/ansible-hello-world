# Proxmox Authentication Setup Guide

## Current Error
```
Module failed: Couldn't authenticate user: root@pam to https://192.168.1.10:8006/api2/json/access/ticket
```

## Root Cause
The Jenkins credential `proxmox-password` is either:
1. Not configured in Jenkins
2. Has the wrong credential ID
3. Contains incorrect password
4. Not being passed to the Ansible playbook correctly

## Solution Steps

### Step 1: Verify Jenkins Credential Exists

1. Go to Jenkins: **Manage Jenkins** → **Manage Credentials**
2. Click on: **Stores scoped to Jenkins** → **Global credentials (unrestricted)**
3. Look for credential with ID: `proxmox-password`

**If it doesn't exist, create it:**
- Click **Add Credentials**
- Kind: `Secret text`
- Scope: `Global`
- Secret: `[Your Proxmox root password]`
- ID: `proxmox-password` (must match exactly!)
- Description: `Proxmox API Password`
- Click **OK**

### Step 2: Verify Proxmox Password is Correct

Test the password manually:

```bash
# Test API authentication
curl -k -d "username=root@pam&password=YOUR_PASSWORD" \
  https://192.168.1.10:8006/api2/json/access/ticket
```

**Expected output:**
```json
{
  "data": {
    "ticket": "PVE:root@pam:...",
    "CSRFPreventionToken": "..."
  }
}
```

**If authentication fails:**
- Password is incorrect
- User doesn't have API access
- Proxmox API is not accessible

### Step 3: Alternative - Use Extra Vars (Temporary Testing)

If Jenkins credentials aren't working, test with extra vars:

**Update Jenkinsfile temporarily:**
```groovy
sh '''
  ansible-playbook ansible/create_vms.yml -i ansible/inventory \
    -e "proxmox_api_password=YOUR_ACTUAL_PASSWORD" -v
'''
```

⚠️ **Warning:** This is for testing only! Don't commit passwords to Git.

### Step 4: Alternative - Use Ansible Vault

**Create vault file:**
```bash
cd ansible
ansible-vault create group_vars/all/vault.yml
```

**Add password:**
```yaml
vault_proxmox_password: your_actual_password
```

**Update playbook** (`ansible/create_vms.yml`):
```yaml
vars:
  proxmox_api_password: "{{ vault_proxmox_password }}"
```

**Update Jenkinsfile:**
```groovy
environment {
  ANSIBLE_VAULT_PASSWORD = credentials('ansible-vault-password')
}

// In the stage:
sh '''
  echo "$ANSIBLE_VAULT_PASSWORD" > /tmp/vault_pass
  ansible-playbook ansible/create_vms.yml -i ansible/inventory \
    --vault-password-file /tmp/vault_pass -v
  rm /tmp/vault_pass
'''
```

### Step 5: Alternative - Use API Token (Recommended for Production)

**Create API Token in Proxmox:**
1. SSH to Proxmox or use Web UI
2. Go to: **Datacenter** → **Permissions** → **API Tokens**
3. Click **Add**
4. User: `root@pam`
5. Token ID: `jenkins`
6. Privilege Separation: Uncheck (or configure specific permissions)
7. Click **Add**
8. **Copy the token** (shown only once!)

**Update playbook to use token:**

Edit `ansible/roles/proxmox_vm/defaults/main.yml`:
```yaml
proxmox_api_user: "root@pam"
proxmox_api_token_name: "jenkins"
proxmox_api_token_value: "{{ lookup('env', 'PROXMOX_TOKEN') }}"
```

Edit `ansible/roles/proxmox_vm/tasks/main.yml`:
```yaml
- name: Clone VM from template
  community.general.proxmox_kvm:
    api_user: "{{ proxmox_api_user }}"
    api_token_id: "{{ proxmox_api_token_name }}"
    api_token_secret: "{{ proxmox_api_token_value }}"
    api_host: "{{ proxmox_api_host }}"
    # ... rest of parameters
```

**Update Jenkinsfile:**
```groovy
environment {
  PROXMOX_TOKEN = credentials('proxmox-api-token')
}
```

## Debugging Steps

### 1. Check if credential is accessible in Jenkins

Add to Jenkinsfile temporarily:
```groovy
sh '''
  echo "Password length: ${#PROXMOX_PASSWORD}"
  # Don't print the actual password!
'''
```

### 2. Test Proxmox API connectivity

```bash
# From Jenkins host
curl -k https://192.168.1.10:8006/api2/json/version
```

Should return Proxmox version info.

### 3. Test with Python directly

```python
from proxmoxer import ProxmoxAPI

try:
    proxmox = ProxmoxAPI(
        '192.168.1.10',
        user='root@pam',
        password='YOUR_PASSWORD',
        verify_ssl=False
    )
    print("Authentication successful!")
    print(f"Version: {proxmox.version.get()}")
except Exception as e:
    print(f"Authentication failed: {e}")
```

### 4. Check Proxmox logs

```bash
ssh root@192.168.1.10
tail -f /var/log/pve/tasks/active
tail -f /var/log/daemon.log | grep pveproxy
```

## Common Issues

### Issue 1: Credential ID Mismatch
**Error:** `credentials('proxmox-password')` returns nothing

**Solution:** 
- Verify credential ID in Jenkins is exactly `proxmox-password`
- No typos, case-sensitive
- Check in correct credential store (Global)

### Issue 2: Wrong Username Format
**Error:** Authentication fails even with correct password

**Solution:**
- Username must be: `root@pam` (not just `root`)
- Format: `username@realm`
- Common realms: `pam`, `pve`

### Issue 3: Proxmox User Permissions
**Error:** Authentication succeeds but operations fail

**Solution:**
```bash
# Check user permissions on Proxmox
pveum user list
pveum user permissions root@pam
```

User needs:
- `VM.Allocate` - Create VMs
- `VM.Clone` - Clone from template
- `VM.Config.*` - Configure VMs
- `Datastore.AllocateSpace` - Use storage

### Issue 4: Firewall Blocking API
**Error:** Connection timeout or refused

**Solution:**
```bash
# On Proxmox, check firewall
iptables -L -n | grep 8006

# Allow API port
iptables -A INPUT -p tcp --dport 8006 -j ACCEPT
```

## Quick Test Script

Save as `test_proxmox_auth.py`:
```python
#!/usr/bin/env python3
import sys
from proxmoxer import ProxmoxAPI

host = "192.168.1.10"
user = "root@pam"
password = sys.argv[1] if len(sys.argv) > 1 else input("Password: ")

try:
    print(f"Testing authentication to {host}...")
    proxmox = ProxmoxAPI(host, user=user, password=password, verify_ssl=False)
    
    print("✓ Authentication successful!")
    version = proxmox.version.get()
    print(f"✓ Proxmox version: {version['version']}")
    
    nodes = proxmox.nodes.get()
    print(f"✓ Nodes: {[n['node'] for n in nodes]}")
    
    print("\n✓ All checks passed! Credentials are working.")
    
except Exception as e:
    print(f"✗ Authentication failed: {e}")
    sys.exit(1)
```

**Run it:**
```bash
pip install proxmoxer requests
python3 test_proxmox_auth.py YOUR_PASSWORD
```

## Recommended Solution

**For production, use API tokens instead of passwords:**

1. Create API token in Proxmox
2. Store token in Jenkins credentials
3. Update playbook to use token authentication
4. More secure and auditable

## Next Steps

1. ✅ Verify Jenkins credential exists with correct ID
2. ✅ Test password manually with curl
3. ✅ Check Jenkinsfile credential reference
4. ✅ Run updated pipeline
5. ✅ Check Jenkins console output for password length verification

## Support

If still failing:
1. Check Jenkins console output for the password length message
2. Verify credential ID matches exactly
3. Test password with curl command
4. Check Proxmox logs for authentication attempts
5. Consider using API token instead
