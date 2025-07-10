#!/bin/bash
# PURPOSE: Install CRI-O and Kubernetes, then auto-join the cluster using systemd service that fetches join command from Secrets Manager

set -e

# Variables
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
sudo apt-mark hold kubelet kubeadm kubectl

echo "🚀 Starting services..."
sudo systemctl daemon-reexec
sudo systemctl enable --now crio
sudo systemctl enable kubelet

echo "🛑 Disabling swap permanently..."
sudo swapoff -a
(crontab -l 2>/dev/null; echo "@reboot /sbin/swapoff -a") | crontab -

echo "📝 Writing join script to /usr/local/bin/join_cluster.sh..."
cat <<'EOL' | sudo tee /usr/local/bin/join_cluster.sh
#!/bin/bash
set -e

REGION="us-west-1"
SECRET_ID="deema-kubeadm-join-command"
LOG_FILE="/var/log/k8s-worker-join.log"

echo "[INFO] Starting join process..." | tee -a $LOG_FILE

while true; do
  JOIN_COMMAND=$(aws secretsmanager get-secret-value \
    --region "$REGION" \
    --secret-id "$SECRET_ID" \
    --query SecretString \
    --output text 2>/dev/null)

  if [ -n "$JOIN_COMMAND" ]; then
    echo "[INFO] Successfully retrieved join command. Executing..." | tee -a $LOG_FILE
    eval "$JOIN_COMMAND" | tee -a $LOG_FILE
    break
  fi

  echo "[WARN] Join command not available yet. Retrying in 15s..." | tee -a $LOG_FILE
  sleep 15
done
EOL

chmod +x /usr/local/bin/join_cluster.sh

echo "🔧 Creating systemd service for auto-join..."
cat <<EOF | sudo tee /etc/systemd/system/k8s-join.service
[Unit]
Description=Join Kubernetes cluster
After=network.target crio.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/join_cluster.sh
Restart=on-failure
RestartSec=30
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reexec
sudo systemctl enable --now k8s-join.service
