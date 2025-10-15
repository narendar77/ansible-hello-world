#!/usr/bin/env python3
"""
Test Proxmox API Authentication
Usage: python3 test_proxmox_auth.py [password]
"""

import sys
import os

try:
    from proxmoxer import ProxmoxAPI
    import requests
    # Disable SSL warnings for self-signed certificates
    requests.packages.urllib3.disable_warnings()
except ImportError:
    print("ERROR: Required packages not installed")
    print("Run: pip install proxmoxer requests")
    sys.exit(1)

# Configuration
PROXMOX_HOST = "192.168.1.10"
PROXMOX_USER = "root@pam"
PROXMOX_NODE = "pve"

def test_basic_connectivity():
    """Test if Proxmox API is reachable"""
    print("=" * 50)
    print("1. Testing Basic Connectivity")
    print("=" * 50)
    
    try:
        import socket
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(5)
        result = sock.connect_ex((PROXMOX_HOST, 8006))
        sock.close()
        
        if result == 0:
            print(f"✓ Port 8006 is open on {PROXMOX_HOST}")
            return True
        else:
            print(f"✗ Cannot connect to {PROXMOX_HOST}:8006")
            return False
    except Exception as e:
        print(f"✗ Connection test failed: {e}")
        return False

def test_api_version():
    """Test if API endpoint responds"""
    print("\n" + "=" * 50)
    print("2. Testing API Endpoint")
    print("=" * 50)
    
    try:
        url = f"https://{PROXMOX_HOST}:8006/api2/json/version"
        response = requests.get(url, verify=False, timeout=5)
        
        if response.status_code == 200:
            data = response.json()
            print(f"✓ API is responding")
            print(f"  Version: {data['data']['version']}")
            print(f"  Release: {data['data']['release']}")
            return True
        else:
            print(f"✗ API returned status code: {response.status_code}")
            return False
    except Exception as e:
        print(f"✗ API test failed: {e}")
        return False

def test_authentication(password):
    """Test authentication with provided credentials"""
    print("\n" + "=" * 50)
    print("3. Testing Authentication")
    print("=" * 50)
    print(f"  Host: {PROXMOX_HOST}")
    print(f"  User: {PROXMOX_USER}")
    print(f"  Password: {'*' * len(password)}")
    print()
    
    try:
        # Test with proxmoxer
        proxmox = ProxmoxAPI(
            PROXMOX_HOST,
            user=PROXMOX_USER,
            password=password,
            verify_ssl=False
        )
        
        print("✓ Authentication successful!")
        
        # Get version info
        version = proxmox.version.get()
        print(f"✓ Connected to Proxmox VE {version['version']}")
        
        return proxmox
        
    except Exception as e:
        print(f"✗ Authentication failed: {e}")
        return None

def test_permissions(proxmox):
    """Test if user has required permissions"""
    print("\n" + "=" * 50)
    print("4. Testing Permissions")
    print("=" * 50)
    
    try:
        # List nodes
        nodes = proxmox.nodes.get()
        print(f"✓ Can list nodes: {[n['node'] for n in nodes]}")
        
        # Check if our node exists
        node_exists = any(n['node'] == PROXMOX_NODE for n in nodes)
        if node_exists:
            print(f"✓ Node '{PROXMOX_NODE}' found")
        else:
            print(f"✗ Node '{PROXMOX_NODE}' not found")
            print(f"  Available nodes: {[n['node'] for n in nodes]}")
            return False
        
        # List VMs
        vms = proxmox.nodes(PROXMOX_NODE).qemu.get()
        print(f"✓ Can list VMs: {len(vms)} VMs found")
        
        # List storage
        storage = proxmox.nodes(PROXMOX_NODE).storage.get()
        print(f"✓ Can list storage: {[s['storage'] for s in storage]}")
        
        return True
        
    except Exception as e:
        print(f"✗ Permission test failed: {e}")
        return False

def test_template_exists(proxmox, template_id="100"):
    """Test if template exists"""
    print("\n" + "=" * 50)
    print("5. Testing Template")
    print("=" * 50)
    print(f"  Looking for template ID: {template_id}")
    
    try:
        vms = proxmox.nodes(PROXMOX_NODE).qemu.get()
        
        template = None
        for vm in vms:
            if str(vm['vmid']) == str(template_id):
                template = vm
                break
        
        if template:
            print(f"✓ Template {template_id} found")
            print(f"  Name: {template.get('name', 'N/A')}")
            print(f"  Status: {template.get('status', 'N/A')}")
            
            # Check if it's actually a template
            if template.get('template', 0) == 1:
                print(f"✓ VM {template_id} is a template")
                return True
            else:
                print(f"⚠ VM {template_id} exists but is NOT a template")
                return False
        else:
            print(f"✗ Template {template_id} not found")
            print(f"  Available VMs: {[vm['vmid'] for vm in vms]}")
            return False
            
    except Exception as e:
        print(f"✗ Template test failed: {e}")
        return False

def test_storage(proxmox, storage_name="local-lvm"):
    """Test if storage is available"""
    print("\n" + "=" * 50)
    print("6. Testing Storage")
    print("=" * 50)
    print(f"  Looking for storage: {storage_name}")
    
    try:
        storage_list = proxmox.nodes(PROXMOX_NODE).storage.get()
        
        target_storage = None
        for s in storage_list:
            if s['storage'] == storage_name:
                target_storage = s
                break
        
        if target_storage:
            print(f"✓ Storage '{storage_name}' found")
            print(f"  Type: {target_storage.get('type', 'N/A')}")
            print(f"  Active: {target_storage.get('active', 'N/A')}")
            
            # Get storage status
            status = proxmox.nodes(PROXMOX_NODE).storage(storage_name).status.get()
            total_gb = status.get('total', 0) / (1024**3)
            avail_gb = status.get('avail', 0) / (1024**3)
            used_gb = status.get('used', 0) / (1024**3)
            
            print(f"  Total: {total_gb:.2f} GB")
            print(f"  Used: {used_gb:.2f} GB")
            print(f"  Available: {avail_gb:.2f} GB")
            
            if avail_gb > 10:
                print(f"✓ Sufficient space available")
                return True
            else:
                print(f"⚠ Low disk space (< 10 GB available)")
                return True
        else:
            print(f"✗ Storage '{storage_name}' not found")
            print(f"  Available storage: {[s['storage'] for s in storage_list]}")
            return False
            
    except Exception as e:
        print(f"✗ Storage test failed: {e}")
        return False

def main():
    """Main test function"""
    print("\n" + "=" * 50)
    print("Proxmox API Authentication Test")
    print("=" * 50)
    
    # Get password
    password = None
    if len(sys.argv) > 1:
        password = sys.argv[1]
    else:
        password = os.environ.get('PROXMOX_PASSWORD')
        if not password:
            password = input("Enter Proxmox password: ")
    
    if not password:
        print("ERROR: No password provided")
        print("Usage: python3 test_proxmox_auth.py [password]")
        print("   or: export PROXMOX_PASSWORD='your-password' && python3 test_proxmox_auth.py")
        sys.exit(1)
    
    # Run tests
    all_passed = True
    
    if not test_basic_connectivity():
        all_passed = False
    
    if not test_api_version():
        all_passed = False
    
    proxmox = test_authentication(password)
    if not proxmox:
        all_passed = False
        print("\n" + "=" * 50)
        print("RESULT: Authentication Failed")
        print("=" * 50)
        sys.exit(1)
    
    if not test_permissions(proxmox):
        all_passed = False
    
    if not test_template_exists(proxmox, "100"):
        all_passed = False
    
    if not test_storage(proxmox, "local-lvm"):
        all_passed = False
    
    # Final result
    print("\n" + "=" * 50)
    if all_passed:
        print("RESULT: ✓ All Tests Passed!")
        print("=" * 50)
        print("\nYour Proxmox credentials are working correctly.")
        print("You can proceed with the Jenkins pipeline.")
        sys.exit(0)
    else:
        print("RESULT: ⚠ Some Tests Failed")
        print("=" * 50)
        print("\nPlease fix the issues above before running the pipeline.")
        sys.exit(1)

if __name__ == "__main__":
    main()
