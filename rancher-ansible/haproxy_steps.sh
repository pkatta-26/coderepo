# Install HAProxy
sudo dnf install -y haproxy

# Configure HAProxy
sudo tee /etc/haproxy/haproxy.cfg > /dev/null << 'EOF'
global
    log /dev/log local0
    maxconn 4096

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
    balance roundrobin
    server rancher localhost:80 check
EOF

# Start HAProxy
sudo systemctl enable haproxy
sudo systemctl start haproxy

# Open firewall
sudo firewall-cmd --add-port=3000/tcp --permanent
sudo firewall-cmd --reload

# Access: http://<VM_IP>:3000