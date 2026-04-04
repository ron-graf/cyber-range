#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="$(dirname "$SCRIPT_DIR")/terraform"

cd "$TF_DIR"
ATTACKER_IP=$(terraform output -raw attacker_public_ip 2>/dev/null)

if [ -z "$ATTACKER_IP" ]; then
  echo "ERROR: Range not deployed. Run ./scripts/deploy.sh first."
  exit 1
fi

echo "Connecting to attacker box at $ATTACKER_IP..."
ssh -o StrictHostKeyChecking=no "ranger@${ATTACKER_IP}"
