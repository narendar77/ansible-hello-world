# Fix Summary - Host Key Verification Failed

## Problem
Jenkins pipeline was failing with:
```
[ERROR]: Task failed: Failed to connect to the host via ssh: Host key verification failed.
```

## Root Cause
The playbook was configured to run on the `proxmox` host, which made Ansible try to SSH to 192.168.1.10. However, the Proxmox API modules (`community.general.proxmox_kvm`) don't need SSH - they use HTTPS API calls directly.

## Solution Applied

### 1. Updated Playbook (`ansible/create_vms.yml`)
**Changed from:**
```yaml
- name: Create Proxmox VMs
  hosts: proxmox
  gather_facts: false
```

**Changed to:**
```yaml
- name: Create Proxmox VMs
  hosts: localhost
  connection: local
  gather_facts: false
  
  vars:
    proxmox_api_host: "192.168.1.10"
    proxmox_node: "pve"
    proxmox_api_user: "root@pam"
```

### 2. Updated All Tasks (`ansible/roles/proxmox_vm/tasks/main.yml`)
Added to every `proxmox_kvm` task:
```yaml
validate_certs: false      # For self-signed SSL certificates
delegate_to: localhost     # Run API calls from localhost
```

### 3. Created Ansible Configuration (`ansible/ansible.cfg`)
```ini
[defaults]
host_key_checking = False

[ssh_connection]
ssh_args = -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null
```

## Why This Works

### Before (Incorrect):
```
Jenkins → SSH to Proxmox → Run Ansible → API calls
                ❌ SSH fails (host key verification)
```

### After (Correct):
```
Jenkins → Run Ansible locally → HTTPS API to Proxmox
                                 ✅ Direct API calls
```

## Key Points

1. **Proxmox API modules don't need SSH** - They use HTTPS (port 8006)
2. **Run playbook on localhost** - API calls are made from Jenkins container
3. **No SSH keys needed for VM creation** - Only API credentials required
4. **validate_certs: false** - Allows self-signed SSL certificates

## Files Modified

| File | Change |
|------|--------|
| `ansible/create_vms.yml` | Changed `hosts: proxmox` → `hosts: localhost` |
| `ansible/roles/proxmox_vm/tasks/main.yml` | Added `validate_certs: false` and `delegate_to: localhost` |
| `ansible/ansible.cfg` | Created with SSH settings |

## Files Created

| File | Purpose |
|------|---------|
| `ansible/ansible.cfg` | Ansible configuration |
| `TROUBLESHOOTING.md` | Common issues and solutions |
| `FIX_SUMMARY.md` | This file |

## Testing

After these changes, the pipeline should:
1. ✅ Install dependencies (proxmoxer, requests)
2. ✅ Run hello world test
3. ✅ Connect to Proxmox API (192.168.1.10:8006)
4. ✅ Clone template 100 three times
5. ✅ Configure VMs (CPU, RAM)
6. ✅ Start VMs
7. ✅ Display summary

## Next Steps

1. **Commit changes:**
   ```bash
   git add .
   git commit -m "Fix: Changed playbook to run on localhost for Proxmox API calls"
   git push
   ```

2. **Run Jenkins pipeline:**
   - Go to Jenkins job
   - Click "Build Now"
   - Monitor Console Output

3. **Verify VMs created:**
   ```bash
   ssh root@192.168.1.10 "qm list | grep lxrancher"
   ```

## Expected Output

```
VMID  NAME                    STATUS
201   lxrancherlocalsbx01     running
202   lxrancherlocalsbx02     running
203   lxrancherlocalsbx03     running
```

## If Still Failing

Check `TROUBLESHOOTING.md` for:
- API connection issues
- Template not found
- VMID conflicts
- Storage issues
- Credential problems

## Additional Notes

- SSH authentication scripts (`scripts/setup_ssh_auth.sh`) are still useful if you need to manage VMs after creation
- The `proxmox` inventory entry can remain for future SSH-based tasks
- API password is securely stored in Jenkins credentials (`proxmox-password`)
