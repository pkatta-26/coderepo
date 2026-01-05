#!/bin/bash

echo "=== Post-Reboot Deep Cleanup ==="

# Stop any running services
echo "Stopping services..."
sudo systemctl stop kubelet 2>/dev/null || true
sudo systemctl stop containerd 2>/dev/null || true
sudo systemctl stop rke2-server 2>/dev/null || true
sudo systemctl stop rke2-agent 2>/dev/null || true
sudo systemctl stop k3s 2>/dev/null || true

# Disable services
sudo systemctl disable kubelet 2>/dev/null || true
sudo systemctl disable containerd 2>/dev/null || true
sudo systemctl disable rke2-server 2>/dev/null || true
sudo systemctl disable rke2-agent 2>/dev/null || true

# Remove kubeadm installations
echo "Removing Kubernetes directories..."
sudo rm -rf /etc/kubernetes
sudo rm -rf /var/lib/kubelet
sudo rm -rf /var/lib/etcd
sudo rm -rf /var/lib/dockershim
sudo rm -rf /var/run/kubernetes
sudo rm -rf /run/flannel
sudo rm -rf /etc/cni
sudo rm -rf /opt/cni
sudo rm -rf /var/lib/cni
sudo rm -rf /var/lib/calico
sudo rm -rf /opt/calico
sudo rm -rf /var/log/pods
sudo rm -rf /var/log/containers
sudo rm -rf /var/lib/containerd

# Remove RKE2 installations
echo "Removing RKE2 directories..."
sudo rm -rf /etc/rancher
sudo rm -rf /var/lib/rancher
sudo rm -rf /usr/local/bin/rke2*
sudo rm -rf /var/lib/kubelet

# Remove user kube configs
echo "Removing user configs..."
rm -rf ~/.kube
rm -rf /root/.kube

# Unset environment variables
unset KUBECONFIG
unset CONTAINER_RUNTIME_ENDPOINT

# Remove from bashrc
sed -i '/KUBECONFIG/d' ~/.bashrc
sed -i '/rancher/d' ~/.bashrc
sed -i '/rke2/d' ~/.bashrc

# Remove kubectl/helm binaries
sudo rm -f /usr/local/bin/kubectl
sudo rm -f /usr/local/bin/helm
sudo rm -f /usr/local/bin/crictl
sudo rm -f /usr/local/bin/ctr

# Check systemd units
echo "Cleaning systemd..."
sudo rm -f /etc/systemd/system/kubelet.service
sudo rm -f /etc/systemd/system/kubelet.service.d/*.conf
sudo rm -f /etc/systemd/system/rke2-server.service
sudo rm -f /etc/systemd/system/rke2-agent.service
sudo rm -rf /etc/systemd/system/kubelet.service.d
sudo systemctl daemon-reload
sudo systemctl reset-failed

# Clean network interfaces (again)
echo "Cleaning network interfaces..."
for iface in $(ip link show | grep -oE 'cali[a-z0-9]+|flannel\.[0-9]+|cni[0-9]+|veth[a-z0-9]+|tunl[0-9]+'); do
    sudo ip link delete $iface 2>/dev/null || true
done

sudo ip link delete cni0 2>/dev/null || true
sudo ip link delete flannel.1 2>/dev/null || true
sudo ip link delete kube-ipvs0 2>/dev/null || true
sudo ip link delete kube-bridge 2>/dev/null || true
sudo ip link delete docker0 2>/dev/null || true

# Clean iptables completely
echo "Cleaning iptables..."
sudo iptables -F
sudo iptables -X 2>/dev/null || true
sudo iptables -t nat -F
sudo iptables -t nat -X 2>/dev/null || true
sudo iptables -t mangle -F
sudo iptables -t mangle -X 2>/dev/null || true
sudo iptables -t raw -F
sudo iptables -t raw -X 2>/dev/null || true

# Clean ipvs
sudo ipvsadm --clear 2>/dev/null || true

# Remove kernel modules
echo "Removing kernel modules..."
sudo modprobe -r ipip 2>/dev/null || true
sudo modprobe -r ip_vs 2>/dev/null || true
sudo modprobe -r ip_vs_rr 2>/dev/null || true
sudo modprobe -r ip_vs_wrr 2>/dev/null || true
sudo modprobe -r ip_vs_sh 2>/dev/null || true

# Clean yum repos
sudo rm -f /etc/yum.repos.d/kubernetes.repo
sudo rm -f /etc/yum.repos.d/rancher*.repo

echo ""
echo "=== Verification ==="
echo ""
echo "Kubernetes directories:"
ls /etc/kubernetes 2>/dev/null || echo "✓ Not found"
ls /var/lib/kubelet 2>/dev/null || echo "✓ Not found"

echo ""
echo "RKE2 directories:"
ls /etc/rancher 2>/dev/null || echo "✓ Not found"
ls /var/lib/rancher 2>/dev/null || echo "✓ Not found"

echo ""
echo "Kubeconfig:"
echo $KUBECONFIG
[ -z "$KUBECONFIG" ] && echo "✓ Not set"

echo ""
echo "Running services:"
systemctl is-active kubelet 2>/dev/null || echo "✓ kubelet not running"
systemctl is-active rke2-server 2>/dev/null || echo "✓ rke2-server not running"

echo ""
echo "Network interfaces:"
ip link show | grep -E "cali|flannel|cni|veth" || echo "✓ No CNI interfaces"

echo ""
echo "Disk space on /var:"
df -h /var | grep -v Filesystem

echo ""
echo "✓ Deep cleanup complete!"
echo ""
echo "System is clean. Ready for fresh RKE2 installation."