#!/bin/bash
set -e

echo "[TOKEN] 🔁 Refreshing kubeadm join token..."

# 🧠 Generate new kubeadm join command with sudo
JOIN_CMD=$(echo "sudo $(kubeadm token create --print-join-command)")
echo "$JOIN_CMD" > /tmp/k8s_join.sh
echo "[TOKEN] ✅ New join command generated."

# 🧰 Install AWS CLI if not already installed
if ! command -v aws &> /dev/null; then
  echo "[TOKEN] 🧰 Installing AWS CLI..."
  curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
  unzip -q awscliv2.zip
  sudo ./aws/install
fi

# ✅ Update the value in AWS Secrets Manager
SECRET_ID=${SECRET_ID:-deema-kubeadm-join-command}
REGION=${AWS_REGION:-us-west-1}

echo "[TOKEN] 🔐 Updating AWS Secrets Manager (secret: $SECRET_ID, region: $REGION)..."
aws secretsmanager put-secret-value \
  --secret-id "$SECRET_ID" \
  --secret-string file:///tmp/k8s_join.sh \
  --region "$REGION"

echo "[TOKEN] 🎉 Token refreshed successfully."
