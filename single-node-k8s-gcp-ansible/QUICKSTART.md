# Quick Start Guide

Follow these 6 simple steps to install Kubernetes with your GCP service account.

## Prerequisites

- GCP project with a VM running RHEL/CentOS/Rocky Linux
- Service account named `devops` created in GCP
- `gcloud` CLI installed on your local machine
- Ansible installed on your local machine

---

## Step 1: Edit Configuration

Open `setup-gcp.sh` and update these 4 lines:

```bash
PROJECT_ID="your-project-id"          # Your GCP project ID
ZONE="us-central1-a"                  # Your VM's zone
VM_NAME="your-vm-name"                # Your VM instance name
SA_EMAIL="devops@${PROJECT_ID}.iam.gserviceaccount.com"  # Your service account email
```

---

## Step 2: Run Setup Script

```bash
./setup-gcp.sh
```

**What it does:**
- ✓ Verifies your VM and service account exist
- ✓ Attaches the service account to your VM
- ✓ Enables IP forwarding
- ✓ Updates configuration files automatically

---

## Step 3: Verify Configuration

```bash
ansible-playbook -i inventory/hosts.ini verify-gcp.yml
```

**Check for:**
- ✓ Service account match: YES
- ✓ IP forwarding: Enabled

---

## Step 4: Install Kubernetes

```bash
ansible-playbook -i inventory/hosts.ini site.yml
```

**Wait for:** ~5-10 minutes for installation to complete

---

## Step 5: Access Your Cluster

Get your VM's IP from the setup script output, then:

```bash
# SSH to the VM
ssh ec2-user@YOUR_VM_IP

# Verify cluster
export KUBECONFIG=/home/ec2-user/.kube/config
kubectl get nodes

# Should show:
# NAME      STATUS   ROLES           AGE   VERSION
# control   Ready    control-plane   1m    v1.29.6
```

---

## Step 6: Test Pod Networking

```bash
# Create test deployment
kubectl create deployment nginx --image=nginx --replicas=2

# Check pods are running
kubectl get pods -o wide

# Verify networking
kubectl exec -it deployment/nginx -- curl localhost
```

---

## Troubleshooting

### Problem: Service Account Mismatch

**Error message:** "VM is not using the expected service account"

**Fix:**
```bash
./setup-gcp.sh
# Answer 'y' when prompted to attach service account
```

---

### Problem: Cannot SSH to VM

**Fix:**
```bash
gcloud compute ssh your-vm-name --zone=your-zone
```

---

### Problem: Pods Can't Communicate

**Check IP forwarding:**
```bash
# On VM
cat /proc/sys/net/ipv4/ip_forward
# Should be: 1

# If not, run:
echo 1 | sudo tee /proc/sys/net/ipv4/ip_forward
```

---

## What Gets Installed

- ✅ Kubernetes v1.29.6
- ✅ Containerd runtime
- ✅ Calico CNI
- ✅ kubectl, kubeadm, kubelet
- ✅ Single-node cluster (workloads can run on control-plane)

---

## Next Steps

After installation:

1. **Deploy an application:**
   ```bash
   kubectl create deployment hello --image=gcr.io/google-samples/hello-app:1.0
   kubectl expose deployment hello --port=8080
   ```

2. **Access via port-forward:**
   ```bash
   kubectl port-forward deployment/hello 8080:8080
   curl localhost:8080
   ```

3. **Check cluster health:**
   ```bash
   kubectl get pods -A
   kubectl top nodes  # (requires metrics-server)
   ```

---

## Need Help?

Run the verification playbook to diagnose issues:

```bash
ansible-playbook -i inventory/hosts.ini verify-gcp.yml
```

Check the full README.md for detailed troubleshooting steps.
