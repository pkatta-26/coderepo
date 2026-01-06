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