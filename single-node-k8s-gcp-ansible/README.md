# Kubernetes Single-Node Cluster with GCP Service Account Integration

This playbook installs a single-node Kubernetes control-plane on GCP using kubeadm, containerd, Calico CNI, and integrates with your existing GCP service account.

## Key Features

- ✅ Uses VM's attached service account (no key file needed)
- ✅ Automatic GCP metadata verification
- ✅ IP forwarding configuration for pod networking
- ✅ Single-node cluster (control-plane taint removed)
- ✅ RHEL/CentOS/Rocky Linux compatible

## Prerequisites

### On Your Local Machine
- Google Cloud SDK (`gcloud`) installed
- Ansible installed
- SSH access to GCP VM

### On GCP
- VM instance running RHEL 9/10 or compatible
- Service account named `devops` (or your preferred name)
- Service account attached to the VM with `cloud-platform` scope
- At least 2 CPUs and 2GB RAM
- 20GB+ disk space

## Quick Start

### Step 1: Clone or Extract This Directory

```bash
cd single-node-k8s-gcp-ansible
```

### Step 2: Configure GCP Settings

Edit `setup-gcp.sh` and update these values:

```bash
PROJECT_ID="your-project-id"
ZONE="us-central1-a"
VM_NAME="your-vm-name"
SA_EMAIL="devops@your-project-id.iam.gserviceaccount.com"
```

### Step 3: Run GCP Setup Script

```bash
./setup-gcp.sh
```

This script will:
1. Verify your VM exists
2. Verify your service account exists
3. Attach the service account to the VM (if not already attached)
4. Enable IP forwarding on the VM
5. Update `inventory/hosts.ini` and `group_vars/all.yml` with your actual values

### Step 4: Verify GCP Configuration

```bash
ansible-playbook -i inventory/hosts.ini verify-gcp.yml
```

This will display:
- VM service account status
- IP forwarding status
- Network configuration
- Recommendations if anything needs fixing

### Step 5: Install Kubernetes

```bash
ansible-playbook -i inventory/hosts.ini site.yml
```

The playbook will:
1. Verify the correct service account is attached
2. Configure IP forwarding
3. Install containerd
4. Install Kubernetes components
5. Initialize the control-plane
6. Install Calico CNI
7. Remove control-plane taint for single-node scheduling

### Step 6: Access Your Cluster

```bash
# SSH to your VM
ssh ec2-user@YOUR_VM_EXTERNAL_IP

# Use kubectl
export KUBECONFIG=/home/ec2-user/.kube/config
kubectl get nodes
kubectl get pods -A
```

## Configuration Files

### `group_vars/all.yml`

Main configuration file. Key variables:

```yaml
# Kubernetes settings
kubernetes_version: "1.29.6"
pod_network_cidr: "192.168.0.0/16"

# GCP settings (updated by setup-gcp.sh)
gcp_project_id: "your-project-id"
gcp_zone: "us-central1-a"
gcp_service_account_email: "devops@your-project-id.iam.gserviceaccount.com"

# Feature flags
enable_gcp_integration: true
enable_ip_forwarding: true
use_vm_service_account: true
```

### `inventory/hosts.ini`

Ansible inventory (updated by setup-gcp.sh):

```ini
[control]
control ansible_host=YOUR_VM_EXTERNAL_IP ansible_user=ec2-user ansible_connection=ssh ansible_become=true instance_name=your-vm-name
```

## How Service Account Works

### No Key File Needed!

This setup uses the service account **attached to the VM** rather than a key file:

1. **Attach service account to VM:**
   ```bash
   gcloud compute instances set-service-account VM_NAME \
     --zone=ZONE \
     --service-account=devops@PROJECT.iam.gserviceaccount.com \
     --scopes=cloud-platform
   ```

2. **VM automatically gets credentials** from GCP metadata server

3. **Kubernetes uses these credentials** via environment variables

### Benefits

- ✅ No sensitive key files to manage
- ✅ More secure (credentials never leave GCP)
- ✅ Automatic rotation (managed by GCP)
- ✅ Easier to audit

## Verification Commands

```bash
# Check if on GCP
curl -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/id

# Check VM's service account
curl -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/email

# Check IP forwarding (on VM)
cat /proc/sys/net/ipv4/ip_forward
# Should return: 1

# Check Kubernetes nodes
kubectl get nodes -o wide

# Check all pods
kubectl get pods -A
```

## Troubleshooting

### Service Account Not Attached

**Error:** "VM is not using the expected service account"

**Solution:**
```bash
gcloud compute instances set-service-account VM_NAME \
  --zone=ZONE \
  --service-account=devops@PROJECT.iam.gserviceaccount.com \
  --scopes=cloud-platform
```

### IP Forwarding Disabled

**Error:** Pod-to-pod networking doesn't work

**Solution:**
```bash
# On your local machine
gcloud compute instances update VM_NAME \
  --zone=ZONE \
  --can-ip-forward

# On the VM
echo 1 | sudo tee /proc/sys/net/ipv4/ip_forward
sudo sysctl --system
```

### Cannot SSH to VM

**Solution:**
```bash
# Add SSH key to GCP
gcloud compute instances add-metadata VM_NAME \
  --zone=ZONE \
  --metadata ssh-keys="ec2-user:$(cat ~/.ssh/id_rsa.pub)"

# Or use gcloud ssh
gcloud compute ssh VM_NAME --zone=ZONE
```

### Kubernetes Components Not Starting

**Check logs:**
```bash
# Kubelet logs
sudo journalctl -u kubelet -f

# Container logs
sudo crictl ps -a
sudo crictl logs CONTAINER_ID
```

## Manual Service Account Attachment

If you prefer to attach the service account manually:

```bash
# Stop the VM
gcloud compute instances stop VM_NAME --zone=ZONE

# Attach service account
gcloud compute instances set-service-account VM_NAME \
  --zone=ZONE \
  --service-account=devops@PROJECT.iam.gserviceaccount.com \
  --scopes=cloud-platform

# Start the VM
gcloud compute instances start VM_NAME --zone=ZONE
```

## Required GCP Permissions

Your service account needs these roles:

```bash
# View current roles
gcloud projects get-iam-policy PROJECT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.members:serviceAccount:devops@PROJECT.iam.gserviceaccount.com"

# Grant roles (if needed)
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:devops@PROJECT.iam.gserviceaccount.com" \
  --role="roles/compute.admin"
```

## Cleanup

To remove the cluster:

```bash
# SSH to VM
ssh ec2-user@VM_IP

# Reset cluster
sudo kubeadm reset -f
sudo rm -rf /etc/kubernetes /var/lib/kubelet /var/lib/etcd /home/ec2-user/.kube
sudo systemctl stop kubelet containerd
```

## Files in This Directory

```
single-node-k8s-gcp-ansible/
├── README.md                    # This file
├── site.yml                     # Main Ansible playbook
├── verify-gcp.yml              # GCP verification playbook
├── setup-gcp.sh                # GCP configuration script
├── group_vars/
│   └── all.yml                 # Configuration variables
├── inventory/
│   └── hosts.ini              # Ansible inventory
└── files/                      # (empty - no key files needed)
```

## Advanced Configuration

### Custom Kubernetes Version

Edit `group_vars/all.yml`:

```yaml
kubernetes_version: "1.30.0"  # Change to desired version
```

### Custom Pod Network CIDR

Edit `group_vars/all.yml`:

```yaml
pod_network_cidr: "10.244.0.0/16"  # Change to desired range
```

### Disable GCP Integration

Edit `group_vars/all.yml`:

```yaml
enable_gcp_integration: false
```

## Support

For issues or questions:

1. Check `verify-gcp.yml` output for diagnostic information
2. Review logs: `sudo journalctl -u kubelet -f`
3. Check GCP console for VM and service account configuration

## License

This is based on the original single-node Kubernetes Ansible playbook with GCP service account integration added.
