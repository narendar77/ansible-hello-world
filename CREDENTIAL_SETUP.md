# Jenkins Credential Setup - VERIFIED PASSWORD

## ✅ Password Verified Working

Your Proxmox password has been verified and works correctly:
- **Host:** 192.168.1.10
- **User:** root@pam
- **Password:** reddy007 ✓ (tested successfully)

## Setup Jenkins Credential

### Step 1: Add Credential to Jenkins

1. **Open Jenkins** in your browser
2. Go to: **Manage Jenkins** → **Manage Credentials**
3. Click: **Stores scoped to Jenkins** → **Global credentials (unrestricted)**
4. Click: **Add Credentials** (on the left)

### Step 2: Fill in Credential Details

```
Kind: Secret text
Scope: Global (Jenkins, nodes, items, all child items, etc)
Secret: reddy007
ID: proxmox-password
Description: Proxmox API Password for 192.168.1.10
```

**IMPORTANT:** The ID must be exactly `proxmox-password` (case-sensitive, no spaces)

### Step 3: Save and Verify

1. Click **OK** to save
2. You should see the credential listed with ID: `proxmox-password`
3. The secret will be hidden (shown as `******`)

### Step 4: Run Jenkins Pipeline

1. Go to your Jenkins job: `Proxmox-VM-Creation` (or whatever you named it)
2. Click **Build Now**
3. Monitor the **Console Output**

You should see:
```
Checking Proxmox password environment variable...
PROXMOX_PASSWORD is set (length: 8)
```

Then the VMs should be created successfully!

## Alternative: Test Without Jenkins First

If you want to test the playbook locally before running in Jenkins:

```bash
cd ansible
export PROXMOX_PASSWORD='reddy007'
ansible-playbook create_vms.yml -i inventory -v
```

This will create the VMs directly from your machine.

## Troubleshooting

### If Jenkins still shows authentication error:

1. **Check credential ID matches exactly:**
   - Must be: `proxmox-password`
   - Not: `proxmox_password` or `PROXMOX_PASSWORD` or anything else

2. **Check credential scope:**
   - Must be: **Global**
   - Not: System or other scopes

3. **Verify in Jenkinsfile:**
   - Line 10 should be: `PROXMOX_PASSWORD = credentials('proxmox-password')`
   - The ID in quotes must match your credential ID

4. **Check Jenkins logs:**
   - If credential not found, Jenkins will show: "Credentials 'proxmox-password' not found"

### If you see "Credentials not found":

The credential ID doesn't match. Either:
- Change the credential ID in Jenkins to `proxmox-password`
- Or update Jenkinsfile line 10 to match your credential ID

## Security Note

⚠️ **Never commit passwords to Git!**

The password `reddy007` should only be stored in:
- Jenkins credentials (encrypted)
- Ansible Vault (encrypted)
- Environment variables (temporary)

Do NOT add it to any files that will be committed to Git.

## Next Steps

1. ✅ Add credential to Jenkins with ID: `proxmox-password`
2. ✅ Verify credential is saved
3. ✅ Run Jenkins pipeline
4. ✅ Check console output for success message
5. ✅ Verify VMs created: `ssh root@192.168.1.10 "qm list | grep lxrancher"`

## Expected Result

After successful run, you should have 3 VMs:

```
VMID  NAME                    STATUS
201   lxrancherlocalsbx01     running
202   lxrancherlocalsbx02     running
203   lxrancherlocalsbx03     running
```
