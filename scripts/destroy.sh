#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
TF_DIR="$ROOT_DIR/terraform"

echo "============================================"
echo "  SmallCo Cyber Range - Destroy"
echo "============================================"
echo ""
echo "This will destroy ALL range infrastructure."
read -p "Are you sure? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
  echo "Aborted."
  exit 0
fi

cd "$TF_DIR"
terraform destroy -auto-approve

echo ""
echo "============================================"
echo "  Range destroyed. Monthly cost: \$0.00"
echo "============================================"
