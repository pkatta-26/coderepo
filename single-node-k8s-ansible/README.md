# Kubernetes Single-Node Cluster Installation (kubeadm, containerd, Calico)

This playbook installs a single-node Kubernetes control-plane on RHEL 10.0 using kubeadm, containerd as the container runtime, and Calico as the CNI.

## Contents
- Inventory: [inventory/hosts.ini](inventory/hosts.ini)
- Variables: [group_vars/all.yml](group_vars/all.yml)
- Playbook: [site.yml](site.yml)

## Prerequisites
- RHEL 10.0 (or compatible) host with sudo access.
- Outbound internet access for package repos and Kubernetes/Calico manifests.
- At least 2 CPUs and 2GB RAM recommended.
- Sufficient disk space (at least 20GB; 100GB recommended for production workloads).

## Default settings (overridable)
See [group_vars/all.yml](group_vars/all.yml):
- `kubernetes_version: 1.29.6`
- `pod_network_cidr: 192.168.0.0/16`
- `cni_manifest_url: https://raw.githubusercontent.com/projectcalico/calico/v3.27.3/manifests/calico.yaml`
- `container_runtime: containerd`
- `cgroup_driver: systemd`
- `firewalld_state: stopped` (firewalld disabled for simpler networking; adjust if needed)

## Deploy
```bash
cd /home/ec2-user/ansible-k8s/single-node-ansible
ansible-playbook -i inventory/hosts.ini site.yml --become
```
If Ansible is installed via pip at `/usr/local/bin/ansible-playbook`:
```bash
sudo /usr/local/bin/ansible-playbook -i inventory/hosts.ini site.yml --become
```

The playbook will:
1) Disable swap and configure kernel modules (overlay, br_netfilter).
2) Install Docker CE repo and containerd.io package.
3) Configure containerd with SystemdCgroup enabled.
4) Install kubelet, kubeadm, kubectl from official Kubernetes repos.
5) Initialize the control-plane with `kubeadm init`.
6) Install Calico CNI.
7) Copy kubeconfig to `/home/ec2-user/.kube/config`.
8) Ensure kubelet is started and enabled.

## Access the cluster
After deployment, you can manage the cluster as `ec2-user`:
```bash
export KUBECONFIG=/home/ec2-user/.kube/config
kubectl get nodes
kubectl get pods -A
```
Or run as root:
```bash
sudo -u ec2-user KUBECONFIG=/home/ec2-user/.kube/config kubectl get nodes
```

## Verification
```bash
kubectl get nodes
# Expected: control-plane node in Ready state

kubectl get pods -A
# Expected: all system pods Running (calico, coredns, kube-proxy, control-plane components)
```

## Single-node scheduling
By default, control-plane nodes have a taint preventing workload scheduling. This playbook **does not** remove the taint during initial setup. To schedule workloads on the control-plane:
```bash
kubectl taint nodes --all node-role.kubernetes.io/control-plane- --overwrite
```
(The rancher-ansible playbook removes this taint automatically.)

## Disk pressure handling
For small root volumes, kubelet may trigger disk-pressure taints. The eviction thresholds can be adjusted in `/var/lib/kubelet/config.yaml`:
```yaml
evictionHard:
  nodefs.available: "100Mi"
  nodefs.inodesFree: "1%"
  imagefs.available: "100Mi"
  imagefs.inodesFree: "1%"
```
Restart kubelet after changes:
```bash
sudo systemctl restart kubelet
```

## Cleanup
To reset the cluster (destructive):
```bash
sudo kubeadm reset -f
sudo rm -rf /etc/kubernetes /var/lib/kubelet /var/lib/etcd /home/ec2-user/.kube
sudo systemctl stop kubelet containerd
```

## Notes
- Firewalld is disabled by default; adjust `firewalld_state` in vars if you need it running with appropriate rules.
- Control-plane components (etcd, api-server, scheduler, controller-manager) run as static pods.
- The playbook is idempotent and can be re-run safely; `kubeadm init` is gated by `/etc/kubernetes/admin.conf`.
- Kernel modules (br_netfilter) require `kernel-modules-extra` on RHEL 10.
- Containerd config is regenerated from `containerd config default` and modified to enable SystemdCgroup.
