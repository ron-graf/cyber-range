#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
TF_DIR="$ROOT_DIR/terraform"
ANSIBLE_DIR="$ROOT_DIR/ansible"

echo "============================================"
echo "  SmallCo Cyber Range - Deploy"
echo "============================================"

# Check prerequisites
for cmd in terraform ansible-playbook gcloud; do
  if ! command -v "$cmd" &> /dev/null; then
    echo "ERROR: $cmd is required but not installed."
    exit 1
  fi
done

# Check for terraform.tfvars
if [ ! -f "$TF_DIR/terraform.tfvars" ]; then
  echo "ERROR: terraform/terraform.tfvars not found."
  echo "Copy terraform.tfvars.example and fill in your GCP project ID:"
  echo "  cp terraform/terraform.tfvars.example terraform/terraform.tfvars"
  exit 1
fi

# Phase 1: Terraform
echo ""
echo "[1/3] Provisioning infrastructure with Terraform..."
cd "$TF_DIR"
terraform init -input=false
terraform apply -auto-approve

# Phase 2: Generate Ansible inventory
echo ""
echo "[2/3] Generating Ansible inventory..."
terraform output -raw ansible_inventory > "$ANSIBLE_DIR/inventory/hosts.ini"
echo "Inventory written to ansible/inventory/hosts.ini"

# Get attacker IP for user
ATTACKER_IP=$(terraform output -raw attacker_public_ip)

# Phase 3: Ansible configuration
echo ""
echo "[3/3] Configuring hosts with Ansible..."
echo "Waiting 30s for VMs to boot..."
sleep 30

cd "$ANSIBLE_DIR"
ansible-playbook playbooks/site.yml -v

echo ""
echo "============================================"
echo "  SmallCo Cyber Range - DEPLOYED"
echo "============================================"
echo ""
echo "  Attacker SSH:  ssh ranger@${ATTACKER_IP}"
echo "  Web Portal:    http://10.0.1.20 (from attacker)"
echo "  Range Info:    ~/RANGE_INFO.md (on attacker)"
echo ""
echo "  To tear down:  ./scripts/destroy.sh"
echo "============================================"
