# Kubernetes Single-Node with Specific GCP Service Account

This Ansible playbook installs Kubernetes and uses a **specific GCP service account** that you choose, even if your VM has multiple service accounts attached.

## Key Feature: Choose Your Service Account

Unlike other setups that use the VM's default service account, this allows you to:

✅ **Specify exactly which service account to use**  
✅ **Work with VMs that have multiple service accounts**  
✅ **Override the default service account**  
✅ **No key files needed** - uses GCP metadata API

## How It Works

```
Your VM may have multiple service accounts:
├── default-compute@developer.gserviceaccount.com  ← Default
├── devops@project.iam.gserviceaccount.com        ← You want THIS one
└── monitoring@project.iam.gserviceaccount.com    ← For monitoring

This playbook lets you specify: devops@project.iam.gserviceaccount.com
```

The playbook will:
1. Check if your specified service account is attached to the VM
2. Verify it can get an access token for that specific service account
3. Configure Kubernetes to use that service account
4. Create a helper script to get tokens for that service account

## Prerequisites

- GCP project with VM running RHEL/CentOS/Rocky Linux
- **Multiple service accounts** (optional, but that's the point!)
- Your chosen service account attached to the VM
- gcloud CLI on your local machine
- Ansible on your local machine

## Quick Start

### Step 1: Edit Configuration

Edit `setup-gcp.sh`:

```bash
PROJECT_ID="your-project-id"
ZONE="us-central1-a"
VM_NAME="your-vm-name"
SA_EMAIL="devops@your-project-id.iam.gserviceaccount.com"  # ← Your specific SA
```

Edit `group_vars/all.yml`:

```yaml
gcp_service_account_email: "devops@your-project-id.iam.gserviceaccount.com"
```

### Step 2: Run Setup Script

```bash
./setup-gcp.sh
```

This will:
- Verify your VM exists
- Check if your specific service account is attached
- Attach it if needed (with your permission)
- Enable IP forwarding
- Update configuration files

### Step 3: Verify Configuration

```bash
ansible-playbook -i inventory/hosts.ini verify-gcp.yml
```

Expected output:
```
ALL AVAILABLE SERVICE ACCOUNTS ON VM:
  default-compute@developer.gserviceaccount.com
  devops@your-project.iam.gserviceaccount.com    ← This one!
  monitoring@project.iam.gserviceaccount.com

CONFIGURED SERVICE ACCOUNT:
Email: devops@your-project.iam.gserviceaccount.com
Accessible: YES ✓
Has Valid Token: YES ✓
```

### Step 4: Install Kubernetes

```bash
ansible-playbook -i inventory/hosts.ini site.yml
```

### Step 5: Access Your Cluster

```bash
ssh ec2-user@YOUR_VM_IP
export KUBECONFIG=/home/ec2-user/.kube/config
kubectl get nodes
```

## Configuration Details

### Specifying Service Account

In `group_vars/all.yml`:

```yaml
# The specific service account you want to use
gcp_service_account_email: "devops@your-project-id.iam.gserviceaccount.com"

# Use specific service account (not VM's default)
use_specific_service_account: true

# Don't use VM's default service account
use_vm_default_service_account: false
```

### How Service Account is Used

The playbook accesses your specific service account via GCP metadata:

```bash
# Get token for your specific service account
curl -H "Metadata-Flavor: Google" \
  "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/devops@project.iam.gserviceaccount.com/token"
```

A helper script is installed on the VM:

```bash
# On the VM
/usr/local/bin/get-gcp-sa-token.sh
# Returns: ya29.c.Kl6zB... (access token)
```

## Multiple Service Accounts Example

Your VM setup might look like this:

```yaml
VM: my-k8s-node
Service Accounts:
  1. default-compute@developer.gserviceaccount.com
     - Purpose: Default GCP compute operations
     - Scopes: cloud-platform
     
  2. devops@my-project.iam.gserviceaccount.com
     - Purpose: Kubernetes and deployment (YOU WANT THIS)
     - Scopes: cloud-platform
     - Roles: compute.admin, storage.admin
     
  3. monitoring@my-project.iam.gserviceaccount.com
     - Purpose: Monitoring and logging
     - Scopes: monitoring.write, logging.write
```

This playbook ensures Kubernetes uses `devops@...` specifically.

## Attaching Service Account to VM

If your service account isn't attached yet:

```bash
# Attach the service account
gcloud compute instances set-service-account VM_NAME \
  --zone=ZONE \
  --service-account=devops@PROJECT.iam.gserviceaccount.com \
  --scopes=cloud-platform

# Restart VM (required)
gcloud compute instances stop VM_NAME --zone=ZONE
gcloud compute instances start VM_NAME --zone=ZONE
```

Or use `./setup-gcp.sh` which does this for you.

## Verification Commands

### Check All Service Accounts on VM

```bash
# From your local machine
gcloud compute instances describe VM_NAME --zone=ZONE \
  --format='value(serviceAccounts[].email)'

# From the VM
curl -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/
```

### Check Your Specific Service Account

```bash
# From the VM
curl -H "Metadata-Flavor: Google" \
  "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/devops@PROJECT.iam.gserviceaccount.com/"
```

### Get Access Token

```bash
# Using the helper script (on VM)
/usr/local/bin/get-gcp-sa-token.sh

# Or manually
curl -H "Metadata-Flavor: Google" \
  "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/devops@PROJECT.iam.gserviceaccount.com/token"
```

## Troubleshooting

### Service Account Not Accessible

**Error:**
```
ERROR: The specified service account is not accessible on this VM!
Service account: devops@project.iam.gserviceaccount.com
Status: 404
```

**Fix:**
```bash
# Attach the service account
./setup-gcp.sh
# Answer 'y' when prompted to attach

# Or manually:
gcloud compute instances set-service-account VM_NAME \
  --zone=ZONE \
  --service-account=devops@PROJECT.iam.gserviceaccount.com \
  --scopes=cloud-platform
```

### Wrong Service Account Being Used

**Check which one is configured:**
```bash
cat group_vars/all.yml | grep gcp_service_account_email
```

**Verify on VM:**
```bash
ansible-playbook -i inventory/hosts.ini verify-gcp.yml
```

### Multiple Service Accounts But Want Different One

Edit `group_vars/all.yml`:

```yaml
# Change this to your preferred service account
gcp_service_account_email: "different-sa@project.iam.gserviceaccount.com"
```

Then re-run the playbook.

## Environment Variables

After installation, these are set on the VM:

```bash
# In /etc/environment and ~/.bashrc
GCP_SERVICE_ACCOUNT=devops@your-project.iam.gserviceaccount.com
GCE_PROJECT_ID=your-project-id
GCE_ZONE=us-central1-a
```

## Files Created

- `/usr/local/bin/get-gcp-sa-token.sh` - Helper script to get access tokens
- `/etc/systemd/system/kubelet.service.d/20-gcp.conf` - Kubelet GCP config
- `/etc/environment` - Global environment variables

## Advanced Usage

### Use VM's Default Service Account Instead

If you want to use whatever service account is the VM's default:

```yaml
# In group_vars/all.yml
use_specific_service_account: false
use_vm_default_service_account: true
# gcp_service_account_email is ignored
```

### Check Which Service Account Kubernetes is Using

```bash
# On the VM
echo $GCP_SERVICE_ACCOUNT

# Or check kubelet config
systemctl cat kubelet | grep GCE_SERVICE_ACCOUNT
```

## Why This Approach?

**Traditional approach:**
- VM uses its default service account
- Can't choose which one if multiple exist
- Have to change VM configuration to change service accounts

**This approach:**
- Explicitly specify which service account to use
- Works with multiple service accounts on same VM
- Clear configuration in code
- Easy to change without modifying VM

## What Gets Installed

- Kubernetes v1.29.6
- Containerd runtime
- Calico CNI
- kubectl, kubeadm, kubelet
- GCP service account integration

## Support

Run verification to diagnose issues:

```bash
ansible-playbook -i inventory/hosts.ini verify-gcp.yml
```

The verification playbook will show:
- All service accounts on the VM
- Which one you're trying to use
- Whether it's accessible
- Whether it can get tokens
- Exact commands to fix issues

## License

Based on the original single-node Kubernetes playbook with specific GCP service account selection added.
