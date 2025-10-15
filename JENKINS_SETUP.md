# Quick Jenkins Setup Guide

## Prerequisites Checklist

- [ ] Proxmox host (192.168.1.10) is accessible
- [ ] Template 100 (rockyos-gold) exists on Proxmox
- [ ] Jenkins has Docker support enabled
- [ ] You have Proxmox root password

## Step-by-Step Jenkins Configuration

### 1. Add Proxmox Credentials to Jenkins

1. Go to: **Jenkins Dashboard** → **Manage Jenkins** → **Manage Credentials**
2. Click: **Stores scoped to Jenkins** → **Global credentials (unrestricted)** → **Add Credentials**
3. Fill in:
   ```
   Kind: Secret text
   Scope: Global
   Secret: [Your Proxmox root password]
   ID: proxmox-password
   Description: Proxmox API Password
   ```
4. Click **OK**

### 2. Create Pipeline Job

1. **Jenkins Dashboard** → **New Item**
2. Enter name: `Proxmox-VM-Creation`
3. Select: **Pipeline**
4. Click **OK**

### 3. Configure Pipeline

In the job configuration page:

**General Section:**
- Description: `Create 3 VMs on Proxmox (lxrancherlocalsbx01-03)`

**Pipeline Section:**
- Definition: `Pipeline script from SCM`
- SCM: `Git`
- Repository URL: `[Your Git repo URL]`
- Credentials: `[Select if private repo]`
- Branch Specifier: `*/main` (or your branch)
- Script Path: `Jenkinsfile`

Click **Save**

### 4. Run the Pipeline

1. Click **Build Now**
2. Watch the progress in **Console Output**

## Expected Pipeline Stages

1. ✅ **Install Dependencies** - Installs Python packages and Ansible collections
2. ✅ **Run Hello World** - Tests Ansible connectivity
3. ✅ **Create Proxmox VMs** - Creates 3 VMs from template

## What Gets Created

| Hostname | VMID | Cores | Memory | IP |
|----------|------|-------|--------|-----|
| lxrancherlocalsbx01 | 201 | 2 | 2048 MB | DHCP |
| lxrancherlocalsbx02 | 202 | 2 | 2048 MB | DHCP |
| lxrancherlocalsbx03 | 203 | 2 | 2048 MB | DHCP |

## Troubleshooting

### Build Fails at "Install Dependencies"
- **Cause**: Docker image cannot install packages
- **Fix**: Check Jenkins Docker configuration and internet connectivity

### Build Fails at "Create Proxmox VMs"
- **Cause**: Cannot connect to Proxmox API
- **Fix**: 
  - Verify Proxmox host is reachable: `ping 192.168.1.10`
  - Check credential ID is exactly `proxmox-password`
  - Verify Proxmox API is accessible on port 8006

### "Template not found" Error
- **Cause**: Template ID 100 doesn't exist
- **Fix**: 
  - SSH to Proxmox: `qm list` to see available templates
  - Update `ansible/roles/proxmox_vm/defaults/main.yml` with correct template ID

### "VMID already exists" Error
- **Cause**: VMs with IDs 201, 202, 203 already exist
- **Fix**: 
  - Delete existing VMs or change VMIDs in `defaults/main.yml`
  - On Proxmox: `qm destroy 201 202 203`

## Customization

To modify VM specifications, edit: `ansible/roles/proxmox_vm/defaults/main.yml`

```yaml
vms:
  - hostname: "lxrancherlocalsbx01"
    vmid: "201"
    cores: 4              # Change CPU
    memory: 4096          # Change RAM (MB)
    ipconfig: "ip=dhcp"   # Or static IP
```

Commit and push changes, then run the pipeline again.

## Verification

After successful build, verify on Proxmox:

```bash
ssh root@192.168.1.10
qm list | grep lxrancher
```

You should see 3 running VMs.

## Clean Up

To delete the VMs:

```bash
ssh root@192.168.1.10
qm stop 201 && qm destroy 201
qm stop 202 && qm destroy 202
qm stop 203 && qm destroy 203
```

## Next Steps

- Configure static IPs if needed
- Install additional software on VMs
- Set up monitoring
- Configure backups

## Support Commands

**Check Jenkins logs:**
```
View Console Output in Jenkins UI
```

**Test Proxmox connectivity:**
```bash
curl -k https://192.168.1.10:8006/api2/json/version
```

**List Proxmox VMs:**
```bash
ssh root@192.168.1.10 "qm list"
```
