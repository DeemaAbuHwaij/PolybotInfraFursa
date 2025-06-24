#!/bin/bash
set -e

KUBERNETES_VERSION=v1.32

# Update & install basic tools
sudo apt-get update
sudo apt-get install jq unzip ebtables ethtool -y

# Install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Enable IPv4 forwarding
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.ipv4.ip_forward = 1
EOF
sudo sysctl --system

# Add Kubernetes and CRI-O repositories
curl -fsSL https://pkgs.k8s.io/core:/stable:/$KUBERNETES_VERSION/deb/Release.key | \
    sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/$KUBERNETES_VERSION/deb/ /" | \
    sudo tee /etc/apt/sources.list.d/kubernetes.list

curl -fsSL https://pkgs.k8s.io/addons:/cri-o:/prerelease:/main/deb/Release.key | \
    sudo gpg --dearmor -o /etc/apt/keyrings/cri-o-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/cri-o-apt-keyring.gpg] https://pkgs.k8s.io/addons:/cri-o:/prerelease:/main/deb/ /" | \
    sudo tee /etc/apt/sources.list.d/cri-o.list

sudo apt-get update
sudo apt-get install -y software-properties-common apt-transport-https ca-certificates curl gpg
sudo apt-get install -y cri-o kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

# Start CRI-O and kubelet
sudo systemctl start crio.service
sudo systemctl enable --now crio.service
sudo systemctl enable --now kubelet

# Disable swap
swapoff -a
(crontab -l ; echo "@reboot /sbin/swapoff -a") | crontab -

# Create dynamic join script
cat <<'EOF' > /opt/k8s-join.sh
#!/bin/bash
set -e

if [ -f /etc/kubernetes/kubelet.conf ]; then
  echo "✅ Node already joined. Skipping."
  exit 0
fi

# Wait until aws CLI is available
for i in {1..10}; do
  if command -v aws &> /dev/null; then break; fi
  echo "⏳ Waiting for AWS CLI..."
  sleep 5
done

# Fetch join command from Secrets Manager
JOIN_CMD=$(aws secretsmanager get-secret-value \
  --secret-id kubeadm_join_command \
  --region us-west-1 \
  --query SecretString \
  --output text)

if [ -z "$JOIN_CMD" ]; then
  echo "❌ Failed to retrieve join command"
  exit 1
fi

echo "🚀 Executing: $JOIN_CMD"
eval "$JOIN_CMD"
EOF

chmod +x /opt/k8s-join.sh

# Create systemd unit
cat <<EOF > /etc/systemd/system/k8s-join.service
[Unit]
Description=Kubernetes Worker Join Script
After=network.target crio.service

[Service]
Type=oneshot
ExecStart=/opt/k8s-join.sh
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
EOF

# Enable it
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable k8s-join.service
