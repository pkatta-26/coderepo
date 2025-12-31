#!/bin/bash

set -e

# Configuration - UPDATE THESE VALUES
PROJECT_ID="your-project-id"
ZONE="us-central1-a"
VM_NAME="your-vm-name"
SA_EMAIL="devops@${PROJECT_ID}.iam.gserviceaccount.com"

echo "================================================"
echo "GCP Service Account Setup for Kubernetes"
echo "================================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
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

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    echo -e "${RED}ERROR: gcloud CLI not found${NC}"
    echo "Please install Google Cloud SDK: https://cloud.google.com/sdk/docs/install"
    exit 1
fi

print_status 0 "gcloud CLI found"

# Set project
echo ""
echo "Setting GCP project..."
gcloud config set project $PROJECT_ID > /dev/null 2>&1
print_status $? "Project set to: $PROJECT_ID"

# Check if VM exists
echo ""
echo "Checking VM..."
VM_EXISTS=$(gcloud compute instances describe $VM_NAME --zone=$ZONE --format='value(name)' 2>/dev/null || echo "")

if [ -z "$VM_EXISTS" ]; then
    echo -e "${RED}✗ VM '$VM_NAME' not found in zone $ZONE${NC}"
    echo ""
    echo "Available VMs:"
    gcloud compute instances list --filter="zone:$ZONE" --format="table(name,zone,machineType,status)"
    exit 1
fi

print_status 0 "VM found: $VM_NAME"

# Check if service account exists
echo ""
echo "Checking service account..."
SA_EXISTS=$(gcloud iam service-accounts describe $SA_EMAIL --format='value(email)' 2>/dev/null || echo "")

if [ -z "$SA_EXISTS" ]; then
    echo -e "${RED}✗ Service account '$SA_EMAIL' not found${NC}"
    echo ""
    echo "Available service accounts:"
    gcloud iam service-accounts list --format="table(email,displayName)"
    exit 1
fi

print_status 0 "Service account found: $SA_EMAIL"

# Check current VM service account
echo ""
echo "Checking VM service account attachment..."
CURRENT_SA=$(gcloud compute instances describe $VM_NAME \
    --zone=$ZONE \
    --format='value(serviceAccounts[0].email)' 2>/dev/null || echo "")

if [ "$CURRENT_SA" == "$SA_EMAIL" ]; then
    print_status 0 "VM already using correct service account: $SA_EMAIL"
else
    if [ -z "$CURRENT_SA" ]; then
        print_warning "VM has no service account attached"
    else
        print_warning "VM currently using different service account: $CURRENT_SA"
    fi
    
    echo ""
    read -p "Attach $SA_EMAIL to $VM_NAME? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Attaching service account (this will stop and restart the VM)..."
        gcloud compute instances set-service-account $VM_NAME \
            --zone=$ZONE \
            --service-account=$SA_EMAIL \
            --scopes=cloud-platform
        
        print_status $? "Service account attached"
        
        echo ""
        echo "Restarting VM..."
        gcloud compute instances stop $VM_NAME --zone=$ZONE --quiet
        gcloud compute instances start $VM_NAME --zone=$ZONE --quiet
        
        echo "Waiting for VM to start..."
        sleep 10
        
        print_status 0 "VM restarted"
    else
        echo "Skipping service account attachment"
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
    read -p "Enable IP forwarding on $VM_NAME? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Enabling IP forwarding..."
        gcloud compute instances update $VM_NAME \
            --zone=$ZONE \
            --can-ip-forward
        
        print_status $? "IP forwarding enabled"
    else
        echo "Skipping IP forwarding (may cause pod networking issues)"
    fi
fi

# Get VM details
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
echo "Project ID:        $PROJECT_ID"
echo "Zone:              $ZONE"
echo "VM Name:           $VM_NAME"
echo "External IP:       $VM_EXTERNAL_IP"
echo "Internal IP:       $VM_INTERNAL_IP"
echo "Service Account:   $SA_EMAIL"
echo "IP Forwarding:     $([ "$IP_FORWARD" == "True" ] && echo "Enabled ✓" || echo "Disabled ✗")"
echo "================================================"
echo ""

# Update inventory file
echo "Updating inventory/hosts.ini..."
if [ -f "inventory/hosts.ini" ]; then
    # Backup original
    cp inventory/hosts.ini inventory/hosts.ini.backup
    
    # Update with actual values
    sed -i.tmp "s/ansible_host=YOUR_VM_EXTERNAL_IP/ansible_host=$VM_EXTERNAL_IP/" inventory/hosts.ini
    sed -i.tmp "s/instance_name=your-vm-name/instance_name=$VM_NAME/" inventory/hosts.ini
    sed -i.tmp "s/gcp_instance_name=your-vm-name/gcp_instance_name=$VM_NAME/" inventory/hosts.ini
    rm -f inventory/hosts.ini.tmp
    
    print_status 0 "inventory/hosts.ini updated"
else
    print_warning "inventory/hosts.ini not found in current directory"
fi

# Update group_vars
echo ""
echo "Updating group_vars/all.yml..."
if [ -f "group_vars/all.yml" ]; then
    # Backup original
    cp group_vars/all.yml group_vars/all.yml.backup
    
    # Update with actual values
    sed -i.tmp "s/gcp_project_id: \"your-project-id\"/gcp_project_id: \"$PROJECT_ID\"/" group_vars/all.yml
    sed -i.tmp "s/gcp_zone: \"us-central1-a\"/gcp_zone: \"$ZONE\"/" group_vars/all.yml
    sed -i.tmp "s/devops@your-project-id.iam.gserviceaccount.com/$SA_EMAIL/" group_vars/all.yml
    rm -f group_vars/all.yml.tmp
    
    print_status 0 "group_vars/all.yml updated"
else
    print_warning "group_vars/all.yml not found in current directory"
fi

echo ""
echo "================================================"
echo "NEXT STEPS"
echo "================================================"
echo "1. Verify configuration:"
echo "   ansible-playbook -i inventory/hosts.ini verify-gcp.yml"
echo ""
echo "2. Install Kubernetes:"
echo "   ansible-playbook -i inventory/hosts.ini site.yml"
echo ""
echo "3. Access the cluster:"
echo "   ssh ec2-user@$VM_EXTERNAL_IP"
echo "   export KUBECONFIG=/home/ec2-user/.kube/config"
echo "   kubectl get nodes"
echo "================================================"
