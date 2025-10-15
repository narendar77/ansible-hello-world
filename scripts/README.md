# SSH Authentication Setup Scripts

These scripts configure SSH key-based authentication between your Jenkins host (192.168.1.141) and Proxmox host (192.168.1.10).

## Available Scripts

### 1. `setup_ssh_auth.sh` (Recommended)
Full-featured script with:
- Host verification
- Automatic backup of existing keys
- SSH config file setup
- Comprehensive error handling
- Detailed verification and reporting

### 2. `setup_ssh_auth_simple.sh`
Minimal script for quick setup:
- Generates SSH key
- Copies to Proxmox
- Tests connection

## Usage

### Option 1: Full Setup (Recommended)

```bash
cd scripts
chmod +x setup_ssh_auth.sh
./setup_ssh_auth.sh
```

**What it does:**
1. Checks you're on the correct host (192.168.1.141)
2. Creates SSH directory if needed
3. Generates RSA 4096-bit key pair
4. Adds Proxmox to known_hosts
5. Copies public key to Proxmox (requires password once)
6. Configures SSH config file with 'proxmox' alias
7. Verifies passwordless authentication
8. Displays summary and public key

**After running, you can connect using:**
```bash
ssh proxmox
# or
ssh root@192.168.1.10
```

### Option 2: Simple Setup

```bash
cd scripts
chmod +x setup_ssh_auth_simple.sh
./setup_ssh_auth_simple.sh
```

**Connect using:**
```bash
ssh -i ~/.ssh/id_rsa_proxmox root@192.168.1.10
```

## Prerequisites

- You must have SSH access to Proxmox with password
- OpenSSH client tools installed (`ssh-keygen`, `ssh-copy-id`)
- Network connectivity to 192.168.1.10

## What Gets Created

### SSH Keys
- **Private key**: `~/.ssh/id_rsa_proxmox`
- **Public key**: `~/.ssh/id_rsa_proxmox.pub`

### SSH Config (full script only)
Location: `~/.ssh/config`

```
Host proxmox
    HostName 192.168.1.10
    User root
    IdentityFile ~/.ssh/id_rsa_proxmox
    StrictHostKeyChecking no
```

## For Jenkins Integration

After running the setup script, you need to add the private key to Jenkins:

### Method 1: SSH Username with Private Key

1. Go to: **Jenkins** → **Manage Jenkins** → **Manage Credentials**
2. Click **Add Credentials**
3. Configure:
   ```
   Kind: SSH Username with private key
   ID: proxmox-ssh-key
   Username: root
   Private Key: Enter directly
   ```
4. Copy content of `~/.ssh/id_rsa_proxmox` and paste it
5. Click **OK**

### Method 2: Secret File

1. Go to: **Jenkins** → **Manage Jenkins** → **Manage Credentials**
2. Click **Add Credentials**
3. Configure:
   ```
   Kind: Secret file
   File: Upload ~/.ssh/id_rsa_proxmox
   ID: proxmox-ssh-key-file
   ```
4. Click **OK**

### Update Jenkinsfile

Uncomment the SSH key section in the Jenkinsfile (lines 30-33):

```groovy
sh '''
  mkdir -p ~/.ssh
  echo "$PROXMOX_SSH_KEY" > ~/.ssh/id_rsa
  chmod 600 ~/.ssh/id_rsa
  ssh-keyscan -H 192.168.1.10 >> ~/.ssh/known_hosts
'''
```

And add to environment section:
```groovy
environment {
  PROXMOX_SSH_KEY = credentials('proxmox-ssh-key')
}
```

## Troubleshooting

### "Permission denied (publickey)"
- Ensure the key was copied correctly
- Check Proxmox `/root/.ssh/authorized_keys` permissions (should be 600)
- Verify `/root/.ssh` directory permissions (should be 700)

### "Connection refused"
- Check Proxmox SSH service: `systemctl status sshd`
- Verify firewall allows SSH: `iptables -L | grep ssh`
- Test basic connectivity: `ping 192.168.1.10`

### "Host key verification failed"
- Remove old host key: `ssh-keygen -R 192.168.1.10`
- Re-run the script

### Script fails on Jenkins host check
- You can continue anyway when prompted
- Or edit the script to change `JENKINS_HOST` variable

## Manual Setup (Alternative)

If scripts don't work, set up manually:

```bash
# 1. Generate key
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa_proxmox -N ""

# 2. Copy to Proxmox
ssh-copy-id -i ~/.ssh/id_rsa_proxmox.pub root@192.168.1.10

# 3. Test
ssh -i ~/.ssh/id_rsa_proxmox root@192.168.1.10 "hostname"
```

## Verification

Test the connection:

```bash
# Should connect without password
ssh root@192.168.1.10 "hostname && pveversion"
```

Expected output:
```
pve
pve-manager/7.x.x/xxxxxxx (running kernel: x.x.x-x-pve)
```

## Security Notes

- Private key (`id_rsa_proxmox`) should **never** be shared or committed to Git
- Keep private key permissions at 600: `chmod 600 ~/.ssh/id_rsa_proxmox`
- Public key can be safely shared
- Consider using SSH agent for key management: `ssh-add ~/.ssh/id_rsa_proxmox`

## Cleanup

To remove SSH authentication:

```bash
# On Jenkins host
rm ~/.ssh/id_rsa_proxmox*

# On Proxmox host
ssh root@192.168.1.10
vi ~/.ssh/authorized_keys
# Remove the line containing "jenkins-to-proxmox"
```
