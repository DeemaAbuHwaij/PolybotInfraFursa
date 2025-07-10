#!/bin/bash
# PURPOSE: This script generates a new kubeadm join token and updates it in AWS Secrets Manager so new worker nodes can join the cluster at any time.

set -e  # Exit immediately if any command fails

echo "[TOKEN] 🔁 Refreshing kubeadm join token..."

# 🧠 Generate a new kubeadm join command and save it to a file
JOIN_CMD=$(echo "sudo $(kubeadm token create --print-join-command)")
echo "$JOIN_CMD" > /tmp/k8s_join.sh
echo "[TOKEN] ✅ New join command generated."

# 🧰 Install AWS CLI if not already installed (for updating Secrets Manager)
if ! command -v aws &> /dev/null; then
  echo "[TOKEN] 🧰 Installing AWS CLI..."
  curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
  unzip -q awscliv2.zip
  sudo ./aws/install
fi

# ✅ Set default values for secret ID and region if not passed via env vars
SECRET_ID=${SECRET_ID:-deema-kubeadm-join-command}
REGION=${AWS_REGION:-us-west-1}

# 🔐 Update the secret in AWS Secrets Manager with the new join command
echo "[TOKEN] 🔐 Updating AWS Secrets Manager (secret: $SECRET_ID, region: $REGION)..."
aws secretsmanager put-secret-value \
  --secret-id "$SECRET_ID" \
  --secret-string file:///tmp/k8s_join.sh \
  --region "$REGION"

echo "[TOKEN] 🎉 Token refreshed successfully."