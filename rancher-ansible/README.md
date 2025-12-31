# Rancher Deployment on Local Kubernetes (Single Node)

This playbook installs Rancher on the existing single-node Kubernetes cluster running on this host. It also installs ingress-nginx with hostPorts to expose Rancher on the node’s public IP via nip.io.

## Contents
- Inventory: [inventory/hosts.ini](inventory/hosts.ini)
- Variables: [group_vars/all.yml](group_vars/all.yml)
- Playbook: [site.yml](site.yml)

## Prerequisites
- Kubernetes control-plane already running on this node (kubeadm-based, containerd, Calico).
- kubeconfig at `/home/ec2-user/.kube/config` and working `kubectl`.
- Ansible available at `/usr/local/bin/ansible-playbook` (installed via pip when Ansible wasn’t in dnf).
- Outbound internet access to fetch Helm charts and images.
- Security group / firewall allows inbound 80/443 to the node public IP.

## Default settings (overridable)
See [group_vars/all.yml](group_vars/all.yml):
- `rancher_hostname: auto` (uses public IPv4 + `.nip.io`)
- `rancher_version: 2.9.2`
- `cert_manager_version: v1.14.4`
- `helm_version: 3.14.4`
- `rancher_bootstrap_password: Admin123!`
- `kubeconfig_path: /home/ec2-user/.kube/config`

## Deploy
```
cd /home/ec2-user/rancher-ansible
sudo /usr/local/bin/ansible-playbook -i inventory/hosts.ini site.yml
```
The playbook will:
1) Install/ensure Helm.
2) Remove control-plane taint (single-node scheduling).
3) Install cert-manager (CRDs + Helm release).
4) Install ingress-nginx as a DaemonSet with hostPorts 80/443.
5) Install/upgrade Rancher with hostname derived from public IP (nip.io) unless overridden.

## Access Rancher
- URL: `https://<public-ip>.nip.io` (self-signed cert). The playbook outputs the exact hostname.
- Login: `admin` with bootstrap password from `rancher_bootstrap_password`.

## Verification
```
kubectl get pods -n cert-manager
kubectl get pods -n ingress-nginx
kubectl get pods -n cattle-system
kubectl get ingress -n cattle-system -o wide
```
All Rancher pods should be Running, and the ingress should show the node address.

## Cleanup
To uninstall Rancher and ingress components:
```
/usr/local/bin/helm uninstall rancher -n cattle-system
kubectl delete namespace cattle-system
/usr/local/bin/helm uninstall cert-manager -n cert-manager
kubectl delete namespace cert-manager
/usr/local/bin/helm uninstall ingress-nginx -n ingress-nginx
kubectl delete namespace ingress-nginx
```

## Notes
- The ingress uses hostPorts; ensure no other service binds 80/443 on the node.
- Disk pressure/taints must be clear for pods to schedule. The playbook taint-tolerates single-node control-plane and will remove the control-plane taint.
- If you override `rancher_hostname`, ensure the DNS entry resolves to this node’s public IP and that 80/443 are reachable.
