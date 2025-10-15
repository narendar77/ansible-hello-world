#!/bin/bash

#############################################
# SSH Authentication Diagnostic Script
#############################################

PROXMOX_HOST="192.168.1.10"
PROXMOX_USER="root"
SSH_KEY_PATH="${HOME}/.ssh/id_rsa_proxmox"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=========================================="
echo "SSH Authentication Diagnostics"
echo "=========================================="
echo ""

# Check 1: SSH key exists
echo "1. Checking SSH key files..."
if [ -f "${SSH_KEY_PATH}" ]; then
    echo -e "${GREEN}✓${NC} Private key exists: ${SSH_KEY_PATH}"
    ls -la "${SSH_KEY_PATH}"
else
    echo -e "${RED}✗${NC} Private key NOT found: ${SSH_KEY_PATH}"
fi

if [ -f "${SSH_KEY_PATH}.pub" ]; then
    echo -e "${GREEN}✓${NC} Public key exists: ${SSH_KEY_PATH}.pub"
    ls -la "${SSH_KEY_PATH}.pub"
else
    echo -e "${RED}✗${NC} Public key NOT found: ${SSH_KEY_PATH}.pub"
fi
echo ""

# Check 2: Key permissions
echo "2. Checking key permissions..."
if [ -f "${SSH_KEY_PATH}" ]; then
    PERMS=$(stat -f "%OLp" "${SSH_KEY_PATH}" 2>/dev/null || stat -c "%a" "${SSH_KEY_PATH}" 2>/dev/null)
    if [ "$PERMS" = "600" ]; then
        echo -e "${GREEN}✓${NC} Private key permissions correct: 600"
    else
        echo -e "${YELLOW}⚠${NC} Private key permissions: ${PERMS} (should be 600)"
        echo "   Fixing permissions..."
        chmod 600 "${SSH_KEY_PATH}"
        echo -e "${GREEN}✓${NC} Fixed"
    fi
fi
echo ""

# Check 3: Network connectivity
echo "3. Testing network connectivity to Proxmox..."
if ping -c 2 -W 2 "${PROXMOX_HOST}" > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Proxmox host is reachable"
else
    echo -e "${RED}✗${NC} Cannot ping Proxmox host"
fi
echo ""

# Check 4: SSH port open
echo "4. Checking if SSH port is open..."
if nc -z -w 2 "${PROXMOX_HOST}" 22 2>/dev/null; then
    echo -e "${GREEN}✓${NC} SSH port 22 is open"
else
    echo -e "${RED}✗${NC} SSH port 22 is not accessible"
fi
echo ""

# Check 5: SSH with verbose output
echo "5. Testing SSH connection with verbose output..."
echo "   Command: ssh -i ${SSH_KEY_PATH} -o BatchMode=yes -v ${PROXMOX_USER}@${PROXMOX_HOST} 'echo success' 2>&1"
echo ""
echo "--- SSH Debug Output ---"
ssh -i "${SSH_KEY_PATH}" -o BatchMode=yes -o ConnectTimeout=5 -v "${PROXMOX_USER}@${PROXMOX_HOST}" "echo 'SSH Success'" 2>&1 | tail -20
echo "--- End Debug Output ---"
echo ""

# Check 6: Try with password authentication to verify credentials
echo "6. Testing basic SSH connectivity (will prompt for password)..."
echo "   If this works, the issue is with key authentication"
echo "   Press Ctrl+C to skip this test"
echo ""
read -p "Press Enter to test password authentication, or Ctrl+C to skip..."
ssh -o PubkeyAuthentication=no "${PROXMOX_USER}@${PROXMOX_HOST}" "echo 'Password auth works'"
echo ""

# Check 7: Display public key
echo "7. Your public key (to manually verify on Proxmox):"
echo "=========================================="
if [ -f "${SSH_KEY_PATH}.pub" ]; then
    cat "${SSH_KEY_PATH}.pub"
else
    echo "Public key not found"
fi
echo "=========================================="
echo ""

# Check 8: Recommendations
echo "8. Troubleshooting recommendations:"
echo ""
echo "   A. Verify key is in Proxmox authorized_keys:"
echo "      ssh ${PROXMOX_USER}@${PROXMOX_HOST} 'cat ~/.ssh/authorized_keys'"
echo ""
echo "   B. Check Proxmox SSH directory permissions:"
echo "      ssh ${PROXMOX_USER}@${PROXMOX_HOST} 'ls -la ~/.ssh/'"
echo ""
echo "   C. Check Proxmox SSH logs:"
echo "      ssh ${PROXMOX_USER}@${PROXMOX_HOST} 'tail -50 /var/log/auth.log | grep sshd'"
echo ""
echo "   D. Manually copy key again:"
echo "      ssh-copy-id -i ${SSH_KEY_PATH}.pub ${PROXMOX_USER}@${PROXMOX_HOST}"
echo ""
echo "   E. Test with explicit key:"
echo "      ssh -i ${SSH_KEY_PATH} ${PROXMOX_USER}@${PROXMOX_HOST}"
echo ""
