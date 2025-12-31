# Troubleshooting Guide

## Common Issues and Solutions

### Issue 1: Service Account Not Attached

**Symptoms:**
```
ERROR: VM is not using the expected service account!
Current: default-compute@developer.gserviceaccount.com
Expected: devops@your-project.iam.gserviceaccount.com
```

**Solution:**
```bash
# Attach the service account
gcloud compute instances set-service-account YOUR_VM_NAME \
  --zone=YOUR_ZONE \
  --service-account=devops@PROJECT.iam.gserviceaccount.com \
  --scopes=cloud-platform

# Restart the VM
gcloud compute instances stop YOUR_VM_NAME --zone=YOUR_ZONE
gcloud compute instances start YOUR_VM_NAME --zone=YOUR_ZONE
```

---

### Issue 2: IP Forwarding Disabled

**Symptoms:**
```
Pods on different nodes cannot communicate
Pod networking issues
```

**Solution:**
```bash
# Enable on GCP
gcloud compute instances update YOUR_VM_NAME \
  --zone=YOUR_ZONE \
  --can-ip-forward

# Enable on the VM
ssh ec2-user@VM_IP
echo 1 | sudo tee /proc/sys/net/ipv4/ip_forward
sudo sysctl -p /etc/sysctl.d/99-kubernetes-cri.conf
```

---

### Issue 3: Cannot Connect via SSH

**Symptoms:**
```
ssh: connect to host X.X.X.X port 22: Connection refused
Permission denied (publickey)
```

**Solution A: Use gcloud SSH**
```bash
gcloud compute ssh YOUR_VM_NAME --zone=YOUR_ZONE
```

**Solution B: Add SSH Key**
```bash
# Generate key if needed
ssh-keygen -t rsa -f ~/.ssh/gcp-key

# Add to VM
gcloud compute instances add-metadata YOUR_VM_NAME \
  --zone=YOUR_ZONE \
  --metadata ssh-keys="ec2-user:$(cat ~/.ssh/gcp-key.pub)"

# Connect
ssh -i ~/.ssh/gcp-key ec2-user@VM_IP
```

**Solution C: Check Firewall**
```bash
# Allow SSH
gcloud compute firewall-rules create allow-ssh \
  --allow tcp:22 \
  --source-ranges 0.0.0.0/0
```

---

### Issue 4: Ansible Connection Failed

**Symptoms:**
```
UNREACHABLE! => {"changed": false, "msg": "Failed to connect to the host"}
```

**Solution:**
```bash
# Test connectivity
ansible -i inventory/hosts.ini control -m ping

# Check inventory
cat inventory/hosts.ini

# Update with correct IP
gcloud compute instances list

# Test manual SSH
ssh ec2-user@VM_IP
```

---

### Issue 5: Kubeadm Init Failed

**Symptoms:**
```
error execution phase preflight: [preflight] Some fatal errors occurred
```

**Solutions:**

**Check swap is disabled:**
```bash
sudo swapoff -a
free -h
```

**Check ports are available:**
```bash
sudo ss -tulpn | grep -E ':(6443|10250|10251|10252|2379|2380)'
```

**Reset and retry:**
```bash
sudo kubeadm reset -f
sudo rm -rf /etc/kubernetes /var/lib/kubelet /var/lib/etcd
ansible-playbook -i inventory/hosts.ini site.yml
```

---

### Issue 6: Kubelet Not Starting

**Symptoms:**
```
kubelet.service: Failed with result 'exit-code'
```

**Check logs:**
```bash
sudo journalctl -u kubelet -f
```

**Common causes:**

**Missing CRI socket:**
```bash
sudo crictl config runtime-endpoint unix:///run/containerd/containerd.sock
sudo systemctl restart kubelet
```

**Containerd not running:**
```bash
sudo systemctl status containerd
sudo systemctl start containerd
sudo systemctl restart kubelet
```

---

### Issue 7: Calico Pods Not Ready

**Symptoms:**
```
calico-node-xxx  0/1  CrashLoopBackOff
```

**Check:**
```bash
kubectl logs -n kube-system calico-node-XXX

# Common fix: IP autodetection
kubectl set env daemonset/calico-node -n kube-system IP_AUTODETECTION_METHOD=interface=eth0
```

---

### Issue 8: CoreDNS Pods Pending

**Symptoms:**
```
coredns-xxx  0/1  Pending
```

**Check:**
```bash
kubectl describe pod -n kube-system coredns-XXX

# Usually: CNI not ready
kubectl get pods -n kube-system | grep calico

# Reapply Calico
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.3/manifests/calico.yaml
```

---

### Issue 9: Service Account Permissions Error

**Symptoms:**
```
Error from server (Forbidden): error when creating
```

**Solution:**
```bash
# Grant necessary roles to service account
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:devops@PROJECT.iam.gserviceaccount.com" \
  --role="roles/compute.admin"

gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:devops@PROJECT.iam.gserviceaccount.com" \
  --role="roles/iam.serviceAccountUser"
```

---

### Issue 10: Disk Space Full

**Symptoms:**
```
no space left on device
```

**Check:**
```bash
df -h
du -sh /var/lib/containerd/*
```

**Clean up:**
```bash
# Remove unused images
sudo crictl rmi --prune

# Remove unused containers
sudo crictl rm $(sudo crictl ps -a -q)

# Clean up logs
sudo journalctl --vacuum-time=3d
```

---

## Diagnostic Commands

### Check GCP Metadata
```bash
# Service account
curl -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/email

# Instance details
curl -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/?recursive=true
```

### Check Kubernetes Components
```bash
# Cluster info
kubectl cluster-info
kubectl get cs  # Component status

# Node status
kubectl get nodes -o wide
kubectl describe node

# All pods
kubectl get pods -A

# Events
kubectl get events -A --sort-by='.lastTimestamp'
```

### Check Networking
```bash
# IP forwarding
cat /proc/sys/net/ipv4/ip_forward

# Network interfaces
ip addr show

# Routes
ip route show

# iptables
sudo iptables -L -n -v
```

### Check Services
```bash
# Kubelet
sudo systemctl status kubelet
sudo journalctl -u kubelet -f

# Containerd
sudo systemctl status containerd
sudo journalctl -u containerd -f

# Container runtime
sudo crictl info
sudo crictl ps -a
```

---

## Still Having Issues?

1. **Run verification playbook:**
   ```bash
   ansible-playbook -i inventory/hosts.ini verify-gcp.yml
   ```

2. **Collect logs:**
   ```bash
   # On the VM
   sudo journalctl -u kubelet > kubelet.log
   kubectl get pods -A > pods.txt
   kubectl describe nodes > nodes.txt
   ```

3. **Reset and retry:**
   ```bash
   sudo kubeadm reset -f
   sudo rm -rf /etc/kubernetes /var/lib/kubelet /var/lib/etcd
   ansible-playbook -i inventory/hosts.ini site.yml
   ```

4. **Check GCP Console:**
   - Verify VM is running
   - Verify service account is attached
   - Check firewall rules
   - Review VM logs

---

## Useful Links

- [Kubernetes Troubleshooting](https://kubernetes.io/docs/tasks/debug/)
- [GCP Compute Metadata](https://cloud.google.com/compute/docs/metadata/overview)
- [Calico Troubleshooting](https://docs.tigera.io/calico/latest/operations/troubleshoot/)
