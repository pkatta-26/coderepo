# Install HAProxy
sudo dnf install -y haproxy

# Get Rancher service IP
export KUBECONFIG=$HOME/.kube/config
RANCHER_IP=$(kubectl get svc rancher -n cattle-system -o jsonpath='{.spec.clusterIP}')

echo "Rancher Service IP: $RANCHER_IP"

# Create HAProxy configuration
sudo tee /etc/haproxy/haproxy.cfg > /dev/null << EOF
global
    log /dev/log local0
    log /dev/log local1 notice
    chroot /var/lib/haproxy
    stats socket /run/haproxy/admin.sock mode 660 level admin
    stats timeout 30s
    user haproxy
    group haproxy
    daemon

defaults
    log     global
    mode    http
    option  httplog
    option  dontlognull
    timeout connect 5000
    timeout client  50000
    timeout server  50000

frontend rancher_frontend
    bind *:3000
    default_backend rancher_backend

backend rancher_backend
    balance roundrobin
    option httpchk GET / HTTP/1.1\r\nHost:\ localhost
    server rancher ${RANCHER_IP}:80 check
EOF

# Test HAProxy configuration
sudo haproxy -c -f /etc/haproxy/haproxy.cfg

# If test passes, enable and start HAProxy
sudo systemctl enable haproxy
sudo systemctl start haproxy

# Check status
sudo systemctl status haproxy



------update

# Create directory with correct permissions
sudo mkdir -p /run/haproxy
sudo chown haproxy:haproxy /run/haproxy
sudo chmod 755 /run/haproxy

# Create config with admin socket
sudo tee /etc/haproxy/haproxy.cfg > /dev/null << 'EOF'
global
    log /dev/log local0
    stats socket /run/haproxy/admin.sock mode 660 level admin
    maxconn 4096
    user haproxy
    group haproxy
    daemon

defaults
    log global
    mode http
    option httplog
    timeout connect 5000ms
    timeout client 50000ms
    timeout server 50000ms

frontend rancher_frontend
    bind *:3000
    default_backend rancher_backend

backend rancher_backend
    server rancher localhost:30000 check
EOF

# Test config
sudo haproxy -c -f /etc/haproxy/haproxy.cfg

# Start HAProxy
sudo systemctl restart haproxy

# Check status
sudo systemctl status haproxy




-----using internal ip

export KUBECONFIG=$HOME/.kube/config

# Get internal IP and NodePort
INTERNAL_IP=$(hostname -I | awk '{print $1}')
NODE_PORT=$(kubectl get svc rancher -n cattle-system -o jsonpath='{.spec.ports[0].nodePort}')

echo "Internal IP: $INTERNAL_IP"
echo "NodePort: $NODE_PORT"

# Create HAProxy config with internal IP
sudo tee /etc/haproxy/haproxy.cfg > /dev/null << EOF
global
    daemon

defaults
    mode http
    timeout connect 5000ms
    timeout client 50000ms
    timeout server 50000ms

frontend rancher_frontend
    bind *:3000
    default_backend rancher_backend

backend rancher_backend
    server rancher ${INTERNAL_IP}:${NODE_PORT} check
EOF

# Test config
sudo haproxy -c -f /etc/haproxy/haproxy.cfg

# Restart HAProxy
sudo systemctl restart haproxy

# Wait
sleep 5

# Test
curl -v http://localhost:3000

# Check backend status
echo ""
echo "Backend status:"
echo "show stat" | sudo socat stdio /var/run/haproxy/admin.sock | grep "^rancher_backend,rancher"




# Set Rancher to use HTTP
kubectl -n cattle-system patch deploy rancher --type=json -p='[
  {
    "op": "add",
    "path": "/spec/template/spec/containers/0/env/-",
    "value": {
      "name": "CATTLE_SERVER_URL",
      "value": "http://'$(hostname -I | awk '{print $1}')':3000"
    }
  }
]'

# Wait for Rancher to restart
kubectl rollout status deployment rancher -n cattle-system

# Test
INTERNAL_IP=$(hostname -I | awk '{print $1}')
curl -I http://$INTERNAL_IP:3000