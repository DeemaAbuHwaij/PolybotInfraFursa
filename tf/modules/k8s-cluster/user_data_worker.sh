#!/bin/bash
set -e

echo "📦 Installing dependencies..."
KUBERNETES_VERSION=v1.32

sudo apt-get update
sudo apt-get install -y jq unzip ebtables ethtool \
  software-properties-common apt-transport-https ca-certificates curl gpg

# Install AWS CLI
echo "☁️ Installing AWS CLI..."
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
sudo ./aws/install

# Enable IPv4 forwarding
echo "🔧 Enabling IPv4 forwarding..."
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.ipv4.ip_forward = 1
EOF
sudo sysctl --system

# Add Kubernetes and CRI-O repositories
echo "🔧 Adding Kubernetes and CRI-O repositories..."
sudo mkdir -p /etc/apt/keyrings

curl -fsSL https://pkgs.k8s.io/core:/stable:/$KUBERNETES_VERSION/deb/Release.key | \
  sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/$KUBERNETES_VERSION/deb/ /" | \
  sudo tee /etc/apt/sources.list.d/kubernetes.list

curl -fsSL https://pkgs.k8s.io/addons:/cri-o:/prerelease:/main/deb/Release.key | \
  sudo gpg --dearmor -o /etc/apt/keyrings/cri-o-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/cri-o-apt-keyring.gpg] https://pkgs.k8s.io/addons:/cri-o:/prerelease:/main/deb/ /" | \
  sudo tee /etc/apt/sources.list.d/cri-o.list

sudo apt-get update
sudo apt-get install -y cri-o kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

# Start CRI-O and kubelet
sudo systemctl start crio
sudo systemctl enable crio
sudo systemctl enable kubelet

# Disable swap
echo "🚫 Disabling swap..."
sudo swapoff -a
(crontab -l ; echo "@reboot /sbin/swapoff -a") | crontab -

# 🧠 Join the worker node to the cluster automatically

echo "🔑 Fetching kubeadm join command from AWS Secrets Manager..."
JOIN_COMMAND=$(aws secretsmanager get-secret-value \
  --region us-west-1 \
  --secret-id deema-kubeadm-join-command \
  --query SecretString \
  --output text)

echo "🚀 Running join command..."
eval "$JOIN_COMMAND"
