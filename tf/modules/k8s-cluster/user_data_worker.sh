#!/bin/bash
set -e

echo "🛠️ Installing dependencies..."
sudo apt-get update
sudo apt-get install -y jq unzip ebtables ethtool software-properties-common apt-transport-https ca-certificates curl gpg

# Set Kubernetes version
KUBERNETES_VERSION=v1.32

echo "📦 Setting up repositories..."
sudo mkdir -p /etc/apt/keyrings

# Kubernetes
curl -fsSL https://pkgs.k8s.io/core:/stable:/$KUBERNETES_VERSION/deb/Release.key | \
  sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/$KUBERNETES_VERSION/deb/ /" | \
  sudo tee /etc/apt/sources.list.d/kubernetes.list

# CRI-O
curl -fsSL https://pkgs.k8s.io/addons:/cri-o:/prerelease:/main/deb/Release.key | \
  sudo gpg --dearmor -o /etc/apt/keyrings/cri-o-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/cri-o-apt-keyring.gpg] https://pkgs.k8s.io/addons:/cri-o:/prerelease:/main/deb/ /" | \
  sudo tee /etc/apt/sources.list.d/cri-o.list

sudo apt-get update
sudo apt-get install -y cri-o kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

echo "🚀 Starting services..."
sudo systemctl enable crio --now
sudo systemctl enable kubelet --now

echo "🚫 Disabling swap..."
sudo swapoff -a
(crontab -l ; echo "@reboot /sbin/swapoff -a") | crontab -

echo "🔧 Enabling IPv4 forwarding..."
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.ipv4.ip_forward = 1
EOF
sudo sysctl --system

echo "☁️ Installing AWS CLI..."
curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
sudo ./aws/install

echo "📄 Creating join script..."
sudo tee /usr/local/bin/k8s-join.sh > /dev/null <<'EOF'
#!/bin/bash
set -e
JOIN_CMD=$(aws secretsmanager get-secret-value \
  --region us-west-1 \
  --secret-id deema-kubeadm-join-command \
  --query SecretString \
  --output text)

if [ -n "$JOIN_CMD" ]; then
  echo "Executing join command..."
  eval "$JOIN_CMD"
else
  echo "Failed to fetch join command from AWS Secrets Manager"
  exit 1
fi
EOF

sudo chmod +x /usr/local/bin/k8s-join.sh

echo "🧩 Creating systemd service for auto-join..."
sudo tee /etc/systemd/system/k8s-join.service > /dev/null <<EOF
[Unit]
Description=Join Kubernetes Cluster
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/k8s-join.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

echo "🔄 Enabling join service..."
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl ena
