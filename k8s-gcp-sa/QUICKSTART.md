# Quick Start: Kubernetes with Specific Service Account

Install Kubernetes using your chosen GCP service account in 4 simple steps.

## Overview

This setup lets you **choose which service account** Kubernetes uses, even if your VM has multiple service accounts attached.

```
Your VM has multiple service accounts:
  ├── default-compute@...
  ├── devops@...          ← YOU CHOOSE THIS ONE
  └── monitoring@...
```

---

## Step 1: Configure (2 minutes)

### Edit `setup-gcp.sh`:

```bash
PROJECT_ID="your-project-id"
ZONE="us-central1-a" 
VM_NAME="your-vm-name"
SA_EMAIL="devops@${PROJECT_ID}.iam.gserviceaccount.com"  # ← Your specific SA
```

### Edit `group_vars/all.yml`:

```yaml
gcp_service_account_email: "devops@your-project-id.iam.gserviceaccount.com"
```

---

## Step 2: Run Setup (3 minutes)

```bash
./setup-gcp.sh
```

**What it does:**
- ✓ Checks if your service account is attached to VM
- ✓ Attaches it if needed (asks permission first)
- ✓ Enables IP forwarding
- ✓ Updates configuration files

**Output you'll see:**
```
ALL AVAILABLE SERVICE ACCOUNTS ON VM:
  - default-compute@developer.gserviceaccount.com
  - devops@your-project.iam.gserviceaccount.com

Target service account: devops@your-project.iam.gserviceaccount.com
✓ Target service account is already attached to VM
```

---

## Step 3: Verify (1 minute)

```bash
ansible-playbook -i inventory/hosts.ini verify-gcp.yml
```

**Look for:**
```
CONFIGURED SERVICE ACCOUNT:
Email: devops@your-project.iam.gserviceaccount.com
Accessible: YES ✓
Has Valid Token: YES ✓
```

If you see ✗ instead of ✓, the verification playbook will show you exact commands to fix it.

---

## Step 4: Install Kubernetes (5-10 minutes)

```bash
ansible-playbook -i inventory/hosts.ini site.yml
```

**Wait for:** Installation to complete

**Success looks like:**
```
TASK [Display final service account info]
ok: [control] => {
    "msg": "Service Account: devops@your-project.iam.gserviceaccount.com ✓"
}
```

---

## Step 5: Access Your Cluster

```bash
# SSH to VM
ssh ec2-user@YOUR_VM_IP

# Verify service account being used
echo $GCP_SERVICE_ACCOUNT
# Output: devops@your-project.iam.gserviceaccount.com

# Use kubectl
export KUBECONFIG=/home/ec2-user/.kube/config
kubectl get nodes

# Get access token for your service account
/usr/local/bin/get-gcp-sa-token.sh
```

---

## Common Scenarios

### Scenario 1: Service Account Not Attached

**Error:**
```
✗ Target service account is NOT attached to VM
```

**Fix:**
```bash
./setup-gcp.sh
# Answer 'y' when prompted to attach service account
```

---

### Scenario 2: Multiple Service Accounts - Want Different One

**Current:**
```yaml
gcp_service_account_email: "devops@project.iam.gserviceaccount.com"
```

**Change to:**
```yaml
gcp_service_account_email: "production@project.iam.gserviceaccount.com"
```

**Then:**
```bash
./setup-gcp.sh  # Attach new service account
ansible-playbook -i inventory/hosts.ini site.yml  # Reinstall
```

---

### Scenario 3: Check Which Service Account is Actually Being Used

```bash
# On the VM
echo $GCP_SERVICE_ACCOUNT

# Check kubelet config
systemctl cat kubelet | grep GCE_SERVICE_ACCOUNT

# Get token for verification
/usr/local/bin/get-gcp-sa-token.sh
```

---

## Verification Checklist

Before installing Kubernetes, verify:

- [ ] Service account exists in GCP
- [ ] Service account is attached to VM
- [ ] Service account has necessary roles (compute.admin, etc.)
- [ ] IP forwarding is enabled
- [ ] Can SSH to VM
- [ ] `verify-gcp.yml` shows all ✓

---

## What Makes This Different?

**Traditional approach:**
```
VM → Uses default service account
     (Can't choose if multiple exist)
```

**This approach:**
```
VM → Has multiple service accounts
     ↓
Your config → Specifies: "Use devops@..."
     ↓
Kubernetes → Uses exactly that one
```

---

## Troubleshooting

### Problem: "Service account not accessible"

```bash
# Check what's attached to VM
gcloud compute instances describe VM_NAME --zone=ZONE \
  --format='value(serviceAccounts[].email)'

# Attach your service account
./setup-gcp.sh
```

### Problem: "Wrong service account being used"

```bash
# Check configuration
cat group_vars/all.yml | grep gcp_service_account_email

# Update it and re-run setup
nano group_vars/all.yml
./setup-gcp.sh
```

### Problem: "Can't get access token"

```bash
# Run verification
ansible-playbook -i inventory/hosts.ini verify-gcp.yml

# Follow the fix commands it suggests
```

---

## Next Steps After Installation

1. **Deploy a test app:**
   ```bash
   kubectl create deployment nginx --image=nginx
   kubectl expose deployment nginx --port=80
   ```

2. **Check pod networking:**
   ```bash
   kubectl get pods -o wide
   kubectl exec deployment/nginx -- curl localhost
   ```

3. **Verify service account in use:**
   ```bash
   /usr/local/bin/get-gcp-sa-token.sh
   ```

---

## Full Documentation

See `README.md` for:
- Detailed explanations
- Multiple service account examples
- Advanced configuration
- Complete troubleshooting guide

---

**You're ready! Start with Step 1 above.** 🚀
