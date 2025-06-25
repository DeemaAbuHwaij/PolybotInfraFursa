#!/bin/bash
set -e

# These instructions are for Kubernetes v1.32
KUBERNETES_VERSION=v1.32

echo "🛠️ Installing dependencies..."
sudo apt-get update
sudo apt-get install -y jq unzip ebtables ethtool

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

# Add CRI-O and Kubernetes repositories
echo "📦 Adding Kubernetes and CRI-O repositories..."
sudo mkdir -p /etc/apt/keyrings

curl -fsSL https://pkgs.k8s.io/core:/stable:/$KUBERNETES_VERSION/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/$KUBERNETES_VERSION/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list

curl -fsSL https://pkgs.k8s.io/addons:/cri-o:/prerelease:/main/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/cri-o-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/cri-o-apt-keyring.gpg] https://pkgs.k8s.io/addons:/cri-o:/prerelease:/main/deb/ /" | sudo tee /etc/apt/sources.list.d/cri-o.list

sudo apt-get update
sudo apt-get install -y software-properties-common apt-transport-https ca-certificates curl gpg
sudo apt-get install -y cri-o kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

# Start CRI-O and kubelet
sudo systemctl start crio
sudo systemctl enable crio
sudo systemctl enable kubelet

# Disable swap permanently
echo "🚫 Disabling swap..."
swapoff -a
(crontab -l ; echo "@reboot /sbin/swapoff -a") | crontab -

# 🧠 Fetch join command
echo "🔑 Fetching kubeadm join command from AWS Secrets Manager..."
JOIN_COMMAND=$(sudo aws secretsmanager get-secret-value \
  --region us-west-1 \
  --secret-id deema-kubeadm-join-command \
  --query SecretString \
  --output text || true)

if [ -n "$JOIN_COMMAND" ]; then
  echo "📄 Writing join script to /opt/k8s-join.sh"
  echo "$JOIN_COMMAND" | sudo tee /opt/k8s-join.sh > /dev/null
  sudo chmod +x /opt/k8s-join.sh

  echo "🛠️ Creating systemd service to run kubeadm join..."
  cat <<EOF | sudo tee /etc/systemd/system/k8s-join.service
[Unit]
Description=Join Kubernetes Cluster
After=network.target

[Service]
Type=oneshot
ExecStart=/opt/k8s-join.sh
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
EOF

  echo "🚀 Enabling and starting k8s-join.service..."
  sudo systemctl daemon-reexec
  sudo systemctl daemon-reload
  sudo systemctl enable --now k8s-join.service
else
  echo "❌ Could not retrieve join command. Skipping join."
fi
