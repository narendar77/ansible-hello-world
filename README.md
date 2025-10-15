# Proxmox VM Creation with Ansible

This project automates the creation of Virtual Machines on Proxmox using Ansible and Jenkins.

## Overview

This automation creates 3 VMs on Proxmox with the following specifications:
- **Proxmox Host**: 192.168.1.10
- **Template**: 100 (rockyos-gold)
- **VM Hostnames**:
  - lxrancherlocalsbx01 (VMID: 201)
  - lxrancherlocalsbx02 (VMID: 202)
  - lxrancherlocalsbx03 (VMID: 203)

## Project Structure

```
.
├── Jenkinsfile                          # Jenkins pipeline definition
├── requirements.txt                     # Python dependencies
├── README.md                           # This file
└── ansible/
    ├── inventory                       # Ansible inventory file
    ├── requirements.yml                # Ansible collection requirements
    ├── hello.yml                       # Test playbook
    ├── create_vms.yml                  # Main VM creation playbook
    └── roles/
        └── proxmox_vm/                 # Proxmox VM role
            ├── defaults/
            │   └── main.yml           # Default variables
            ├── tasks/
            │   └── main.yml           # Main tasks
            └── vars/
                └── main.yml           # Role variables
```

## Prerequisites

### On Proxmox Host
1. **Template VM**: Ensure template ID 100 (rockyos-gold) exists
2. **API Access**: Root user with API access enabled
3. **Storage**: Sufficient storage available (default: local-lvm)
4. **Network**: VMs will use DHCP by default

### On Jenkins
1. **Docker**: Jenkins must have Docker support for running Ansible container
2. **Credentials**: Proxmox password stored in Jenkins credentials
3. **Network Access**: Jenkins must be able to reach Proxmox host (192.168.1.10)

## Jenkins Setup Instructions

### Step 1: Configure Jenkins Credentials

1. Navigate to **Jenkins Dashboard** → **Manage Jenkins** → **Manage Credentials**
2. Select appropriate domain (usually "Global")
3. Click **Add Credentials**
4. Configure:
   - **Kind**: Secret text
   - **Secret**: Your Proxmox root password
   - **ID**: `proxmox-password`
   - **Description**: Proxmox API Password
5. Click **OK**

### Step 2: Create Jenkins Pipeline Job

1. Go to **Jenkins Dashboard** → **New Item**
2. Enter job name: `Proxmox-VM-Creation`
3. Select **Pipeline** and click **OK**
4. In the configuration page:
   - **Description**: "Create 3 VMs on Proxmox using Ansible"
   - Scroll to **Pipeline** section
   - **Definition**: Pipeline script from SCM
   - **SCM**: Git
   - **Repository URL**: Your Git repository URL
   - **Branch**: */main (or your branch name)
   - **Script Path**: Jenkinsfile
5. Click **Save**

### Step 3: Configure SSH Access (Optional but Recommended)

If you want to use SSH key authentication instead of password:

1. Create Jenkins credential for SSH key:
   - **Kind**: Secret text
   - **Secret**: Your private SSH key content
   - **ID**: `proxmox-ssh-key`
   
2. Update the Jenkinsfile to uncomment SSH key configuration lines (lines 30-33)

3. Ensure the public key is added to Proxmox host's `~/.ssh/authorized_keys`

### Step 4: Run the Pipeline

1. Go to your pipeline job
2. Click **Build Now**
3. Monitor the build progress in **Console Output**

The pipeline will:
- Install required Python dependencies (proxmoxer, requests)
- Run a hello world test
- Create 3 VMs from template 100
- Start the VMs

## Customization

### Modify VM Specifications

Edit `ansible/roles/proxmox_vm/defaults/main.yml`:

```yaml
vms:
  - hostname: "lxrancherlocalsbx01"
    vmid: "201"
    cores: 4              # Change CPU cores
    memory: 4096          # Change RAM (MB)
    ipconfig: "ip=dhcp"   # Or set static IP
```

### Change Proxmox Node

If your Proxmox node name is not "pve", update:

```yaml
proxmox_node: "your-node-name"
```

### Use Different Template

Change the template ID:

```yaml
vm_template_id: "100"  # Change to your template ID
```

### Configure Static IPs

Instead of DHCP, set static IPs:

```yaml
ipconfig: "ip=192.168.1.101/24,gw=192.168.1.1"
```

### Enable Cloud-Init

If your template supports cloud-init:

```yaml
use_cloud_init: true
vm_default_user: "admin"
vm_default_password: "{{ lookup('env', 'VM_PASSWORD') }}"
vm_nameservers: "8.8.8.8 8.8.4.4"
```

## Manual Execution (Without Jenkins)

### Local Testing

1. Install dependencies:
```bash
pip install -r requirements.txt
ansible-galaxy collection install -r ansible/requirements.yml
```

2. Set Proxmox password:
```bash
export PROXMOX_PASSWORD='your-password'
```

3. Run the playbook:
```bash
cd ansible
ansible-playbook create_vms.yml -i inventory -v
```

### Using Ansible Vault (Recommended for Production)

1. Create vault file:
```bash
ansible-vault create ansible/group_vars/proxmox/vault.yml
```

2. Add password:
```yaml
vault_proxmox_api_password: your-password
```

3. Update playbook to use vault variable:
```yaml
proxmox_api_password: "{{ vault_proxmox_api_password }}"
```

4. Run with vault:
```bash
ansible-playbook create_vms.yml -i inventory --ask-vault-pass
```

## Troubleshooting

### Issue: "Failed to connect to Proxmox API"
- **Solution**: Verify Proxmox host is reachable: `ping 192.168.1.10`
- Check firewall rules allow API access (port 8006)
- Verify credentials are correct

### Issue: "Template not found"
- **Solution**: Verify template exists: `qm list` on Proxmox host
- Ensure template ID is correct (default: 100)

### Issue: "VMID already exists"
- **Solution**: Change VMID in `defaults/main.yml` or delete existing VMs
- Check existing VMs: `qm list` on Proxmox host

### Issue: "Insufficient storage"
- **Solution**: Check available storage on Proxmox
- Change storage location in `defaults/main.yml`

### Issue: "Permission denied"
- **Solution**: Ensure Proxmox user has VM creation permissions
- Verify API token has correct privileges

## VM Management

### Check VM Status
```bash
ansible proxmox -i ansible/inventory -m shell -a "qm list"
```

### Stop VMs
```bash
ansible-playbook ansible/create_vms.yml -i ansible/inventory -e "start_vms=false"
```

### Delete VMs
Create a cleanup playbook or manually:
```bash
qm stop 201 && qm destroy 201
qm stop 202 && qm destroy 202
qm stop 203 && qm destroy 203
```

## Security Best Practices

1. **Never commit passwords**: Use Jenkins credentials or Ansible Vault
2. **Use SSH keys**: Prefer key-based authentication over passwords
3. **Limit API access**: Create dedicated Proxmox user with minimal permissions
4. **Network security**: Restrict Jenkins to Proxmox network access
5. **Audit logs**: Monitor Proxmox logs for unauthorized access

## Additional Resources

- [Proxmox API Documentation](https://pve.proxmox.com/pve-docs/api-viewer/)
- [Ansible Proxmox Module](https://docs.ansible.com/ansible/latest/collections/community/general/proxmox_kvm_module.html)
- [Jenkins Pipeline Syntax](https://www.jenkins.io/doc/book/pipeline/syntax/)

## Support

For issues or questions:
1. Check the troubleshooting section
2. Review Jenkins console output
3. Check Proxmox logs: `/var/log/pve/tasks/`
4. Verify Ansible verbose output with `-vvv` flag

## License

This project is provided as-is for automation purposes.
