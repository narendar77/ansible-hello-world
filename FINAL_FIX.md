# Final Fix - Template Name vs ID

## Issue
The Proxmox API `clone` parameter expects the **template NAME**, not the ID.

### Error Message
```
VM with name = 100 does not exist in cluster
```

This confirms the module was looking for a VM named "100" instead of using ID 100.

## Solution

### Changed From:
```yaml
clone: "{{ vm_template_id }}"  # Using ID "100"
```

### Changed To:
```yaml
clone: "{{ vm_template_name }}"  # Using name "rockyos-gold"
```

## Files Modified

### 1. `ansible/roles/proxmox_vm/defaults/main.yml`
Added template name variable:
```yaml
vm_template_id: "100"              # Keep for reference
vm_template_name: "rockyos-gold"   # Used for cloning
```

### 2. `ansible/roles/proxmox_vm/tasks/main.yml`
Line 8 changed:
```yaml
clone: "{{ vm_template_name }}"
```

## Why This Works

Proxmox API behavior:
- `clone` parameter: Expects VM/template **NAME** (string)
- `newid` parameter: New VM **ID** (integer)

Your template:
- ID: 100
- Name: rockyos-gold ✅ (This is what we need)

## Commit and Deploy

```bash
git add ansible/roles/proxmox_vm/defaults/main.yml ansible/roles/proxmox_vm/tasks/main.yml FINAL_FIX.md
git commit -m "Fix: Use template name instead of ID for cloning"
git push
```

Then run Jenkins pipeline - should work now! 🎉

## Expected Behavior

The playbook will:
1. Clone "rockyos-gold" → Create VM 201 (lxrancherlocalsbx01)
2. Clone "rockyos-gold" → Create VM 202 (lxrancherlocalsbx02)
3. Clone "rockyos-gold" → Create VM 203 (lxrancherlocalsbx03)
4. Configure resources (CPU, RAM)
5. Start all VMs

## Verification

After successful run:
```bash
ssh root@192.168.1.10 "qm list | grep lxrancher"
```

Should show:
```
201   lxrancherlocalsbx01     running
202   lxrancherlocalsbx02     running
203   lxrancherlocalsbx03     running
```

## Summary of All Issues Fixed

| # | Issue | Solution |
|---|-------|----------|
| 1 | Host key verification failed | Run on localhost, not proxmox host |
| 2 | Authentication failed | Setup Jenkins credential |
| 3 | Clone used wrong parameter | Changed `vmid` → `newid` |
| 4 | Clone used ID instead of name | Changed to use `vm_template_name` ✅ |

This should be the final fix! 🚀
