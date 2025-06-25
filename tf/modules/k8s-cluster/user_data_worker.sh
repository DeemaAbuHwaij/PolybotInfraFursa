#!/bin/bash
set -e

echo "📦 Installing dependencies..."
KUBERNETES_VERSION=v1.32

sudo apt-get update
sudo apt-get install -y jq unzip ebtables ethtool \
  software-properties-common apt-transport-https ca-certificates curl gpg

# Install AWS CLI
if ! command -v aws &>/dev/null; then
  echo "☁️ Installing AWS CLI..."
  curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
  unzip -q awscliv2.zip
  sudo ./aws/install
fi

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

# Start services
sudo systemctl enable --now crio
sudo systemctl enable --now kubelet

# Disable swap
echo "🚫 Disabling swap..."
sudo swapoff -a
(crontab -l 2>/dev/null; echo "@reboot /sbin/swapoff -a") | crontab -

# Fetch join command and store to script
echo "📥 Preparing k8s join script..."
cat <<'EOF' | sudo tee /opt/k8s_join.sh
#!/bin/bash
if [ ! -f /etc/kubernetes/kubelet.conf ]; then
  echo "🔑 Fetching join command from Secrets Manager..."
  JOIN_COMMAND=$(aws secretsmanager get-secret-value \
    --region us-west-1 \
    --secret-id deema-kubeadm-join-command \
    --query SecretString \
    --output text)
  echo "🚀 Joining cluster..."
  eval "$JOIN_COMMAND"
else
  echo "✅ Node already part of the cluster. Skipping."
fi
EOF

sudo chmod +x /opt/k8s_join.sh

# Create systemd service
echo "🔧 Creating systemd unit: k8s-join.service"
cat <<EOF | sudo tee /etc/systemd/system/k8s-join.service
[Unit]
Description=Join Kubernetes Cluster if not already joined
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/opt/k8s_join.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

# Enable and start the service
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable k8s-join.service
sudo systemctl start k8s-join.service
