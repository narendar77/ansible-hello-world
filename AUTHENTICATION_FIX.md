# Authentication Error Fix

## Current Error
```
Module failed: Couldn't authenticate user: root@pam to https://192.168.1.10:8006/api2/json/access/ticket
```

## Quick Fix Checklist

### 1. Verify Jenkins Credential

**Go to Jenkins:**
- Manage Jenkins → Manage Credentials
- Global credentials (unrestricted)
- Look for ID: `proxmox-password`

**If missing, create it:**
```
Kind: Secret text
Scope: Global
Secret: [Your Proxmox root password]
ID: proxmox-password  ← MUST BE EXACTLY THIS
Description: Proxmox API Password
```

### 2. Test Password Manually

**From your terminal:**
```bash
curl -k -d "username=root@pam&password=YOUR_PASSWORD" \
  https://192.168.1.10:8006/api2/json/access/ticket
```

**Should return:**
```json
{"data":{"ticket":"PVE:root@pam:...","CSRFPreventionToken":"..."}}
```

**If it fails:**
- Password is wrong
- User doesn't exist
- API is not accessible

### 3. Use Test Script

**Run the authentication test:**
```bash
cd scripts
pip install proxmoxer requests
python3 test_proxmox_auth.py YOUR_PASSWORD
```

This will test:
- ✓ Network connectivity
- ✓ API endpoint
- ✓ Authentication
- ✓ Permissions
- ✓ Template 100 exists
- ✓ Storage available

### 4. Common Issues

| Issue | Solution |
|-------|----------|
| Credential ID wrong | Must be exactly `proxmox-password` |
| Wrong username format | Must be `root@pam` not just `root` |
| Password has special chars | Ensure it's properly escaped in Jenkins |
| API not accessible | Check firewall, verify port 8006 open |

### 5. Updated Jenkinsfile

I've updated the Jenkinsfile to:
- ✅ Verify `PROXMOX_PASSWORD` is set
- ✅ Show password length (not actual password)
- ✅ Export variable properly to Ansible

**The updated stage will show:**
```
Checking Proxmox password environment variable...
PROXMOX_PASSWORD is set (length: XX)
```

If you see "ERROR: PROXMOX_PASSWORD is not set!" then the Jenkins credential is not configured correctly.

## Step-by-Step Resolution

### Step 1: Commit Updated Jenkinsfile
```bash
git add Jenkinsfile AUTHENTICATION_SETUP.md AUTHENTICATION_FIX.md scripts/test_proxmox_auth.py
git commit -m "Add authentication debugging and test script"
git push
```

### Step 2: Verify Credential in Jenkins
1. Open Jenkins
2. Go to: Manage Jenkins → Manage Credentials
3. Verify `proxmox-password` exists
4. If not, create it with your Proxmox root password

### Step 3: Test Password
```bash
# Test with curl
curl -k -d "username=root@pam&password=YOUR_PASSWORD" \
  https://192.168.1.10:8006/api2/json/access/ticket

# Or use the test script
python3 scripts/test_proxmox_auth.py YOUR_PASSWORD
```

### Step 4: Run Jenkins Pipeline
- Go to your Jenkins job
- Click "Build Now"
- Check Console Output for:
  - "PROXMOX_PASSWORD is set (length: XX)"
  - Authentication success/failure

## Alternative: Use API Token (Recommended)

Instead of password, use API token:

### Create Token in Proxmox:
```bash
ssh root@192.168.1.10
pveum user token add root@pam jenkins --privsep 0
```

Copy the token value (shown only once!)

### Add to Jenkins:
- Credential ID: `proxmox-api-token`
- Kind: Secret text
- Secret: [Token value]

### Update playbook:
See `AUTHENTICATION_SETUP.md` for full instructions.

## Files Created

| File | Purpose |
|------|---------|
| `AUTHENTICATION_SETUP.md` | Detailed authentication guide |
| `AUTHENTICATION_FIX.md` | This quick reference |
| `scripts/test_proxmox_auth.py` | Test script for credentials |
| `Jenkinsfile` (updated) | Added password verification |

## Next Steps

1. ✅ Commit and push changes
2. ✅ Verify Jenkins credential exists
3. ✅ Test password with curl or test script
4. ✅ Run Jenkins pipeline
5. ✅ Check console output for password verification

## If Still Failing

Check the Jenkins console output:
- Does it show "PROXMOX_PASSWORD is set"?
- What's the password length?
- Does curl authentication work?
- Run the test script to verify all components

See `AUTHENTICATION_SETUP.md` for more detailed troubleshooting.
