# Template Not Found Issue

## Current Error
```
Module failed: VM with vmid 201 does not exist in cluster
```

This error is misleading - it's actually saying that the **template (ID 100)** doesn't exist or isn't properly configured.

## Diagnosis

Run the check script to see what templates/VMs exist:

```bash
# Option 1: Using Python (recommended)
python3 scripts/check_template.py

# Option 2: Using SSH
./scripts/check_proxmox_vms.sh
```

## Common Issues & Solutions

### Issue 1: Template 100 Doesn't Exist

**Check available VMs/Templates:**
```bash
ssh root@192.168.1.10 "qm list"
```

**Solution:** Update the template ID in `ansible/roles/proxmox_vm/defaults/main.yml`:
```yaml
vm_template_id: "YOUR_ACTUAL_TEMPLATE_ID"
```

### Issue 2: VM 100 Exists But Is Not a Template

**Check if it's a template:**
```bash
ssh root@192.168.1.10 "qm config 100 | grep template"
```

**Solution A - Convert to template:**
```bash
ssh root@192.168.1.10 "qm template 100"
```

**Solution B - Use different template:**
Find a real template and update `vm_template_id` in defaults.

### Issue 3: Template Name vs ID

Your requirement mentions "100 (rockyos-gold)" - this means:
- Template ID: 100
- Template Name: rockyos-gold

**Verify both match:**
```bash
ssh root@192.168.1.10 "qm config 100 | grep -E '(name|template)'"
```

Should show:
```
name: rockyos-gold
template: 1
```

### Issue 4: Wrong Node Name

**Check node name:**
```bash
ssh root@192.168.1.10 "pvesh get /nodes"
```

**If not "pve", update in `ansible/roles/proxmox_vm/defaults/main.yml`:**
```yaml
proxmox_node: "YOUR_NODE_NAME"
```

### Issue 5: VMIDs Already Exist

**Check if 201, 202, 203 are already used:**
```bash
ssh root@192.168.1.10 "qm list | grep -E '201|202|203'"
```

**Solution A - Delete existing:**
```bash
ssh root@192.168.1.10 "qm stop 201 && qm destroy 201"
ssh root@192.168.1.10 "qm stop 202 && qm destroy 202"
ssh root@192.168.1.10 "qm stop 203 && qm destroy 203"
```

**Solution B - Use different IDs:**
Update `ansible/roles/proxmox_vm/defaults/main.yml`:
```yaml
vms:
  - hostname: "lxrancherlocalsbx01"
    vmid: "301"  # Changed from 201
  - hostname: "lxrancherlocalsbx02"
    vmid: "302"  # Changed from 202
  - hostname: "lxrancherlocalsbx03"
    vmid: "303"  # Changed from 203
```

## Quick Diagnostic Commands

```bash
# 1. List all VMs and templates
ssh root@192.168.1.10 "qm list"

# 2. Check if 100 is a template
ssh root@192.168.1.10 "qm config 100 | grep template"

# 3. Check node name
ssh root@192.168.1.10 "hostname"

# 4. Check if target VMIDs are free
ssh root@192.168.1.10 "qm list | grep -E '201|202|203'"

# 5. Find all templates
ssh root@192.168.1.10 "qm list" | awk '$3 == "1" {print}'
```

## Using the Check Scripts

### Python Script (Detailed)
```bash
cd scripts
python3 check_template.py
```

**Output will show:**
- ✓ Template 100 status
- ✓ Whether it's actually a template
- ✓ Available VMs/Templates if 100 not found
- ✓ Whether VMIDs 201-203 are available
- ✓ Specific actions needed

### Bash Script (Quick)
```bash
cd scripts
./check_proxmox_vms.sh
```

## Most Likely Solutions

### Scenario A: Template doesn't exist
1. Run: `python3 scripts/check_template.py`
2. Find the correct template ID
3. Update `vm_template_id` in `ansible/roles/proxmox_vm/defaults/main.yml`
4. Commit and push
5. Re-run Jenkins pipeline

### Scenario B: VM 100 is not a template
1. Convert it: `ssh root@192.168.1.10 "qm template 100"`
2. Re-run Jenkins pipeline

### Scenario C: VMIDs conflict
1. Delete existing VMs (if safe to do so)
2. Or change target VMIDs in defaults
3. Re-run Jenkins pipeline

## Next Steps

1. **Run diagnostic:**
   ```bash
   python3 scripts/check_template.py
   ```

2. **Fix the issue** based on output

3. **Update configuration** if needed:
   ```bash
   vi ansible/roles/proxmox_vm/defaults/main.yml
   git add ansible/roles/proxmox_vm/defaults/main.yml
   git commit -m "Update template ID or VMIDs"
   git push
   ```

4. **Re-run Jenkins pipeline**

## Files Created

| File | Purpose |
|------|---------|
| `scripts/check_template.py` | Detailed API-based check |
| `scripts/check_proxmox_vms.sh` | Quick SSH-based check |
| `TEMPLATE_ISSUE.md` | This troubleshooting guide |
