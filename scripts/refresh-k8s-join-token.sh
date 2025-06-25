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
  unzip awscliv2.zip
  sudo ./aws/install
fi

# ✅ Update the value in AWS Secrets Manager
echo "[TOKEN] 🔐 Updating AWS Secrets Manager with new join command..."
aws secretsmanager put-secret-value \
  --secret-id K8S_JOIN_COMMAND \
  --secret-string file:///tmp/k8s_join.sh \
  --region ${AWS_REGION:-us-west-1}

echo "[TOKEN] 🎉 Token refreshed successfully."
