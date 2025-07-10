#!/bin/bash
# PURPOSE: This script installs CRI-O and Kubernetes components on a worker EC2 instance
# and joins it to the Kubernetes cluster using a join command securely fetched from AWS Secrets Manager.

set -e  # Exit immediately if a command fails

# Set Kubernetes version and AWS Secrets Manager details
KUBERNETES_VERSION=v1.32
REGION="us-west-1"
SECRET_ID="deema-kubeadm-join-command"

echo "🧩 Installing dependencies..."
sudo apt-get update
sudo apt-get install -y jq unzip ebtables ethtool software-properties-common apt-transport-https ca-certificates curl gpg

echo "🔐 Installing AWS CLI..."
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
sudo ./aws/install

echo "📡 Enabling IPv4 forwarding..."
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.ipv4.ip_forward = 1
EOF
sudo sysctl --system

echo "📦 Adding Kubernetes and CRI-O repositories..."
sudo mkdir -p /etc/apt/keyrings

# Add Kubernetes repo
curl -fsSL https://pkgs.k8s.io/core:/stable:/$KUBERNETES_VERSION/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/$KUBERNETES_VERSION/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list

# Add CRI-O repo
curl -fsSL https://pkgs.k8s.io/addons:/cri-o:/prerelease:/main/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/cri-o-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/cri-o-apt-keyring.gpg] https://pkgs.k8s.io/addons:/cri-o:/prerelease:/main/deb/ /" | sudo tee /etc/apt/sources.list.d/cri-o.list

echo "📦 Installing CRI-O and Kubernetes components..."
sudo apt-get update
sudo apt-get install -y cri-o kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl  # Prevent accidental upgrades

echo "🚀 Starting services..."
sudo systemctl daemon-reexec
sudo systemctl enable --now crio
sudo systemctl enable kubelet

echo "🛑 Disabling swap..."
sudo swapoff -a
(crontab -l 2>/dev/null; echo "@reboot /sbin/swapoff -a") | crontab -

echo "🔑 Fetching kubeadm join command from AWS Secrets Manager..."

# Retry fetching the join command (in case it isn't available yet)
for attempt in {1..10}; do
  JOIN_COMMAND=$(aws secretsmanager get-secret-value \
    --region "$REGION" \
    --secret-id "$SECRET_ID" \
    --query SecretString \
    --output text 2>/dev/null) && break

  echo "⏳ [$attempt] Secret not found yet. Retrying in 15s..."
  sleep 15
done

# Fail if join command couldn't be retrieved
if [ -z "$JOIN_COMMAND" ]; then
  echo "❌ Failed to fetch join command. Exiting."
  exit 1
fi

echo "🤝 Joining the Kubernetes cluster..."
eval "$JOIN_COMMAND"


# Create a systemd service to run the join command at boot
cat <<EOF | sudo tee /etc/systemd/system/k8s-join.service
[Unit]
Description=Join Kubernetes cluster
After=network.target crio.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/join_cluster.sh
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
EOF

# Save your join logic into a script
cat <<'EOL' | sudo tee /usr/local/bin/join_cluster.sh
#!/bin/bash
set -e
REGION="us-west-1"
SECRET_ID="deema-kubeadm-join-command"

for attempt in {1..10}; do
  JOIN_COMMAND=$(aws secretsmanager get-secret-value \
    --region "$REGION" \
    --secret-id "$SECRET_ID" \
    --query SecretString \
    --output text 2>/dev/null) && break
  sleep 15
done

if [ -z "$JOIN_COMMAND" ]; then
  echo "❌ Failed to fetch join command"
  exit 1
fi

eval "$JOIN_COMMAND"
EOL

chmod +x /usr/local/bin/join_cluster.sh
sudo systemctl daemon-reexec
sudo systemctl enable --now k8s-join.service
