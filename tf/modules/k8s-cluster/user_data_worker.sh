#!/bin/bash
set -e

KUBERNETES_VERSION=v1.32

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

echo "📦 Installing CRI-O and Kubernetes components..."
sudo mkdir -p /etc/apt/keyrings

curl -fsSL https://pkgs.k8s.io/core:/stable:/$KUBERNETES_VERSION/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/$KUBERNETES_VERSION/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list

curl -fsSL https://pkgs.k8s.io/addons:/cri-o:/prerelease:/main/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/cri-o-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/cri-o-apt-keyring.gpg] https://pkgs.k8s.io/addons:/cri-o:/prerelease:/main/deb/ /" | sudo tee /etc/apt/sources.list.d/cri-o.list

sudo apt-get update
sudo apt-get install -y cri-o kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

echo "🚀 Starting services..."
sudo systemctl daemon-reexec
sudo systemctl enable --now crio
sudo systemctl enable kubelet

echo "🛑 Disabling swap..."
sudo swapoff -a
(crontab -l 2>/dev/null; echo "@reboot /sbin/swapoff -a") | crontab -

echo "🔧 Creating join script with retry logic..."
cat << 'EOF' | sudo tee /usr/local/bin/k8s-join.sh
#!/bin/bash
set -e

SECRET_ID="deema-kubeadm-join-command"
REGION="us-west-1"

echo "🔑 Attempting to fetch join command from AWS Secrets Manager..."

for attempt in {1..10}; do
  JOIN_COMMAND=$(aws secretsmanager get-secret-value \
    --region "$REGION" \
    --secret-id "$SECRET_ID" \
    --query SecretString \
    --output text 2>/dev/null) && break

  echo "⏳ [$attempt] Secret not found yet. Retrying in 15s..."
  sleep 15
done

if [ -z "$JOIN_COMMAND" ]; then
  echo "❌ Failed to fetch join command after retries. Exiting."
  exit 1
fi

echo "🤝 Joining cluster..."
eval "$JOIN_COMMAND"
EOF

sudo chmod +x /usr/local/bin/k8s-join.sh

echo "🧩 Creating systemd unit to auto-run join on boot..."
cat <<EOF | sudo tee /etc/systemd/system/k8s-join.service
[Unit]
Description=Join Kubernetes Cluster
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/k8s-join.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

echo "🟢 Enabling k8s-join.service..."
sudo systemctl daemon-reexec
sudo systemctl enable k8s-join.service
