#!/bin/bash

set -e

# Configuration - UPDATE THESE VALUES
PROJECT_ID="your-project-id"
ZONE="us-central1-a"
VM_NAME="your-vm-name"
SA_EMAIL="devops@${PROJECT_ID}.iam.gserviceaccount.com"

echo "================================================"
echo "GCP Service Account Setup for Kubernetes"
echo "Using Specific Service Account"
echo "================================================"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $2"
    else
        echo -e "${RED}✗${NC} $2"
    fi
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

# Check gcloud
if ! command -v gcloud &> /dev/null; then
    echo -e "${RED}ERROR: gcloud CLI not found${NC}"
    exit 1
fi

print_status 0 "gcloud CLI found"

# Set project
gcloud config set project $PROJECT_ID > /dev/null 2>&1
print_status $? "Project set: $PROJECT_ID"

# Check VM exists
echo ""
echo "Checking VM..."
VM_EXISTS=$(gcloud compute instances describe $VM_NAME --zone=$ZONE --format='value(name)' 2>/dev/null || echo "")

if [ -z "$VM_EXISTS" ]; then
    echo -e "${RED}✗ VM '$VM_NAME' not found${NC}"
    echo ""
    echo "Available VMs:"
    gcloud compute instances list --filter="zone:$ZONE"
    exit 1
fi

print_status 0 "VM found: $VM_NAME"

# Check service account exists
echo ""
echo "Checking service account..."
SA_EXISTS=$(gcloud iam service-accounts describe $SA_EMAIL --format='value(email)' 2>/dev/null || echo "")

if [ -z "$SA_EXISTS" ]; then
    echo -e "${RED}✗ Service account '$SA_EMAIL' not found${NC}"
    echo ""
    echo "Available service accounts:"
    gcloud iam service-accounts list
    exit 1
fi

print_status 0 "Service account exists: $SA_EMAIL"

# Get current VM service accounts
echo ""
echo "Checking VM service account configuration..."
CURRENT_SAS=$(gcloud compute instances describe $VM_NAME \
    --zone=$ZONE \
    --format='value(serviceAccounts[].email)' 2>/dev/null || echo "")

echo ""
print_info "Current service accounts attached to VM:"
if [ -z "$CURRENT_SAS" ]; then
    echo "  (none)"
else
    echo "$CURRENT_SAS" | tr ' ' '\n' | sed 's/^/  - /'
fi

echo ""
print_info "Target service account: $SA_EMAIL"

# Check if our SA is already attached
if echo "$CURRENT_SAS" | grep -q "$SA_EMAIL"; then
    print_status 0 "Target service account is already attached to VM"
    SA_ATTACHED=true
else
    print_warning "Target service account is NOT attached to VM"
    SA_ATTACHED=false
fi

# Attach service account if needed
if [ "$SA_ATTACHED" = false ]; then
    echo ""
    echo "The VM needs the service account attached to use it."
    echo "This will:"
    echo "  1. Stop the VM"
    echo "  2. Attach the service account: $SA_EMAIL"
    echo "  3. Start the VM"
    echo ""
    read -p "Attach service account to VM? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Stopping VM..."
        gcloud compute instances stop $VM_NAME --zone=$ZONE --quiet
        
        echo "Attaching service account..."
        gcloud compute instances set-service-account $VM_NAME \
            --zone=$ZONE \
            --service-account=$SA_EMAIL \
            --scopes=cloud-platform
        
        print_status $? "Service account attached"
        
        echo "Starting VM..."
        gcloud compute instances start $VM_NAME --zone=$ZONE --quiet
        
        echo "Waiting for VM to start..."
        sleep 10
        
        print_status 0 "VM restarted with new service account"
        SA_ATTACHED=true
    else
        echo "Skipping service account attachment"
        echo ""
        print_warning "Kubernetes installation will fail without this service account!"
    fi
fi

# Check IP forwarding
echo ""
echo "Checking IP forwarding..."
IP_FORWARD=$(gcloud compute instances describe $VM_NAME \
    --zone=$ZONE \
    --format='value(canIpForward)' 2>/dev/null || echo "false")

if [ "$IP_FORWARD" == "True" ]; then
    print_status 0 "IP forwarding already enabled"
else
    print_warning "IP forwarding is disabled"
    
    echo ""
    read -p "Enable IP forwarding? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        gcloud compute instances update $VM_NAME \
            --zone=$ZONE \
            --can-ip-forward
        
        print_status $? "IP forwarding enabled"
    else
        echo "Skipping IP forwarding (may cause pod networking issues)"
    fi
fi

# Get VM IPs
echo ""
echo "Retrieving VM details..."
VM_EXTERNAL_IP=$(gcloud compute instances describe $VM_NAME \
    --zone=$ZONE \
    --format='get(networkInterfaces[0].accessConfigs[0].natIP)')

VM_INTERNAL_IP=$(gcloud compute instances describe $VM_NAME \
    --zone=$ZONE \
    --format='get(networkInterfaces[0].networkIP)')

# Summary
echo ""
echo "================================================"
echo "CONFIGURATION SUMMARY"
echo "================================================"
echo "Project ID:          $PROJECT_ID"
echo "Zone:                $ZONE"
echo "VM Name:             $VM_NAME"
echo "External IP:         $VM_EXTERNAL_IP"
echo "Internal IP:         $VM_INTERNAL_IP"
echo ""
echo "Service Account:     $SA_EMAIL"
echo "  Attached to VM:    $([ "$SA_ATTACHED" = true ] && echo "Yes ✓" || echo "No ✗")"
echo ""
echo "IP Forwarding:       $([ "$IP_FORWARD" == "True" ] && echo "Enabled ✓" || echo "Disabled ✗")"
echo "================================================"
echo ""

# Update configuration files
if [ -f "group_vars/all.yml" ]; then
    echo "Updating group_vars/all.yml..."
    cp group_vars/all.yml group_vars/all.yml.backup
    
    sed -i.tmp "s/gcp_project_id: \"your-project-id\"/gcp_project_id: \"$PROJECT_ID\"/" group_vars/all.yml
    sed -i.tmp "s/gcp_zone: \"us-central1-a\"/gcp_zone: \"$ZONE\"/" group_vars/all.yml
    sed -i.tmp "s|devops@your-project-id.iam.gserviceaccount.com|$SA_EMAIL|" group_vars/all.yml
    rm -f group_vars/all.yml.tmp
    
    print_status 0 "group_vars/all.yml updated"
fi

if [ -f "inventory/hosts.ini" ]; then
    echo "Updating inventory/hosts.ini..."
    cp inventory/hosts.ini inventory/hosts.ini.backup
    
    sed -i.tmp "s/ansible_host=YOUR_VM_EXTERNAL_IP/ansible_host=$VM_EXTERNAL_IP/" inventory/hosts.ini
    sed -i.tmp "s/instance_name=your-vm-name/instance_name=$VM_NAME/" inventory/hosts.ini
    sed -i.tmp "s/gcp_instance_name=your-vm-name/gcp_instance_name=$VM_NAME/" inventory/hosts.ini
    rm -f inventory/hosts.ini.tmp
    
    print_status 0 "inventory/hosts.ini updated"
fi

# Next steps
echo ""
echo "================================================"
echo "NEXT STEPS"
echo "================================================"

if [ "$SA_ATTACHED" = false ]; then
    echo -e "${RED}⚠ WARNING:${NC} Service account not attached!"
    echo "You must attach the service account before proceeding:"
    echo ""
    echo "gcloud compute instances set-service-account $VM_NAME \\"
    echo "  --zone=$ZONE \\"
    echo "  --service-account=$SA_EMAIL \\"
    echo "  --scopes=cloud-platform"
    echo ""
    echo "Then restart the VM and re-run this script."
else
    echo "1. Verify configuration:"
    echo "   ansible-playbook -i inventory/hosts.ini verify-gcp.yml"
    echo ""
    echo "2. Install Kubernetes:"
    echo "   ansible-playbook -i inventory/hosts.ini site.yml"
    echo ""
    echo "3. Access your cluster:"
    echo "   ssh ec2-user@$VM_EXTERNAL_IP"
    echo "   export KUBECONFIG=/home/ec2-user/.kube/config"
    echo "   kubectl get nodes"
fi

echo "================================================"
