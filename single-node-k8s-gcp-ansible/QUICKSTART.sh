#!/bin/bash

# Quick Start Script - Run this to get started quickly

echo "================================================"
echo "Kubernetes on GCP - Quick Start"
echo "================================================"
echo ""

# Check if we're in the right directory
if [ ! -f "setup-gcp.sh" ]; then
    echo "ERROR: Please run this from the single-node-k8s-gcp-ansible directory"
    exit 1
fi

echo "Step 1: Configuration"
echo "---------------------"
echo ""
echo "Edit setup-gcp.sh and update these values:"
echo "  PROJECT_ID=\"your-project-id\""
echo "  ZONE=\"us-central1-a\""
echo "  VM_NAME=\"your-vm-name\""
echo "  SA_EMAIL=\"devops@\${PROJECT_ID}.iam.gserviceaccount.com\""
echo ""
read -p "Have you updated setup-gcp.sh? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Please update setup-gcp.sh first, then run this script again"
    exit 1
fi

echo ""
echo "Step 2: GCP Setup"
echo "----------------"
echo ""
read -p "Run GCP setup script? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    ./setup-gcp.sh
else
    echo "Skipping GCP setup"
fi

echo ""
echo "Step 3: Verification"
echo "-------------------"
echo ""
read -p "Verify GCP configuration? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    ansible-playbook -i inventory/hosts.ini verify-gcp.yml
    
    echo ""
    read -p "Did verification pass? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo ""
        echo "Please fix the issues shown above before continuing"
        echo "See TROUBLESHOOTING.md for help"
        exit 1
    fi
else
    echo "Skipping verification"
fi

echo ""
echo "Step 4: Install Kubernetes"
echo "-------------------------"
echo ""
echo "This will install Kubernetes on your GCP VM (takes 5-10 minutes)"
read -p "Proceed with installation? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    ansible-playbook -i inventory/hosts.ini site.yml
    
    if [ $? -eq 0 ]; then
        echo ""
        echo "================================================"
        echo "SUCCESS! Kubernetes is installed!"
        echo "================================================"
        echo ""
        
        # Get VM IP
        if [ -f "inventory/hosts.ini" ]; then
            VM_IP=$(grep "ansible_host=" inventory/hosts.ini | grep -oP 'ansible_host=\K[^ ]+')
            
            echo "To access your cluster:"
            echo ""
            echo "1. SSH to your VM:"
            echo "   ssh ec2-user@$VM_IP"
            echo ""
            echo "2. Use kubectl:"
            echo "   export KUBECONFIG=/home/ec2-user/.kube/config"
            echo "   kubectl get nodes"
            echo "   kubectl get pods -A"
            echo ""
        fi
        
        echo "================================================"
    else
        echo ""
        echo "Installation failed. Check the output above for errors."
        echo "See TROUBLESHOOTING.md for help"
        exit 1
    fi
else
    echo "Installation skipped"
fi

echo ""
echo "Done! See README.md for next steps."
