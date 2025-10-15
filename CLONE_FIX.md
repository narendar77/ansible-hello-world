# Clone VM Fix - newid vs vmid

## Issue Found

The error "VM with vmid 201 does not exist" was caused by using the wrong parameter in the clone task.

### Template Status ✅
- Template ID: 100
- Name: rockyos-gold
- Status: Template (confirmed with `template: 1`)
- Everything is correctly configured on Proxmox

## Root Cause

When **cloning** a VM in Proxmox, the API requires:
- `clone`: Source template/VM ID (100)
- `newid`: New VM ID to create (201, 202, 203)

We were incorrectly using:
- `vmid`: This is for updating existing VMs, not cloning

## Fix Applied

### Before (Incorrect):
```yaml
- name: Clone VM from template
  community.general.proxmox_kvm:
    clone: "{{ vm_template_id }}"
    vmid: "{{ item.vmid }}"          # ❌ Wrong parameter
    name: "{{ item.hostname }}"
```

### After (Correct):
```yaml
- name: Clone VM from template
  community.general.proxmox_kvm:
    clone: "{{ vm_template_id }}"
    newid: "{{ item.vmid }}"         # ✅ Correct parameter
    name: "{{ item.hostname }}"
```

## What Changed

**File:** `ansible/roles/proxmox_vm/tasks/main.yml`
**Line 9:** Changed `vmid` → `newid`

This tells Proxmox:
- Clone template 100
- Create new VM with ID 201 (then 202, 203)
- Name it lxrancherlocalsbx01 (then 02, 03)

## Next Steps

1. **Commit the fix:**
   ```bash
   git add ansible/roles/proxmox_vm/tasks/main.yml
   git commit -m "Fix: Use newid parameter for VM cloning"
   git push
   ```

2. **Run Jenkins pipeline** - Should now work!

3. **Verify VMs created:**
   ```bash
   ssh root@192.168.1.10 "qm list | grep lxrancher"
   ```

## Expected Result

After successful run:
```
201   lxrancherlocalsbx01     running
202   lxrancherlocalsbx02     running  
203   lxrancherlocalsbx03     running
```

## Additional Check (Optional)

If you want to verify storage is correct:
```bash
./scripts/check_storage.sh
```

This ensures `local-lvm` storage exists and is available.

## Reference

Proxmox API Documentation:
- Clone operation requires `newid` for the new VM ID
- `vmid` is only used when updating existing VMs
- Source: https://pve.proxmox.com/pve-docs/api-viewer/

## Files Modified

| File | Change |
|------|--------|
| `ansible/roles/proxmox_vm/tasks/main.yml` | Line 9: `vmid` → `newid` |

## Files Created

| File | Purpose |
|------|---------|
| `scripts/check_storage.sh` | Verify storage configuration |
| `CLONE_FIX.md` | This documentation |
