#!/bin/bash
set -e

# These instructions are for Kubernetes v1.32.
KUBERNETES_VERSION=v1.32

# Update and install dependencies
sudo apt-get update
sudo apt-get install -y jq unzip ebtables ethtool software-properties-common apt-transport-https ca-certificates curl gpg

# Install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
sudo ./aws/install

# Enable IPv4 forwarding (persists across reboots)
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.ipv4.ip_forward = 1
EOF

# Apply immediately
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

# Install CRI-O and Kubernetes components
sudo apt-get update
sudo apt-get install -y cri-o kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

# Start and enable CRI-O and kubelet
sudo systemctl start crio.service
sudo systemctl enable --now crio.service
sudo systemctl enable --now kubelet

# Disable swap
sudo swapoff -a
(crontab -l ; echo "@reboot /sbin/swapoff -a") | crontab -

# 🧠 Create the join script (runs only once if node is not already joined)
cat <<'EOF' | sudo tee /opt/k8s-join.sh
#!/bin/bash
set -e

if [ -f /etc/kubernetes/kubelet.conf ]; then
  echo "✅ Already part of the cluster. Skipping join."
  exit 0
fi

for i in {1..10}; do
  if command -v aws &>/dev/null; then break; fi
  echo "⏳ Waiting for AWS CLI to be available..."
  sleep 5
done

JOIN_CMD=$(aws secretsmanager get-secret-value \
  --secret-id kubeadm-join-command \
  --region us-west-1 \
  --query SecretString \
  --output text)

if [ -z "$JOIN_CMD" ]; then
  echo "❌ Failed to retrieve join command from Secrets Manager"
  exit 1
fi

FINAL_CMD="$JOIN_CMD --cri-socket unix:///var/run/containerd/containerd.sock"
echo "🚀 Running join command..."
eval "$FINAL_CMD"
EOF

# Make join script executable
sudo chmod +x /opt/k8s-join.sh

# 🧩 Create systemd unit to run join script at startup
cat <<EOF | sudo tee /etc/systemd/system/k8s-join.service
[Unit]
Description=Kubernetes Worker Auto Join
After=network.target crio.service

[Service]
Type=oneshot
ExecStart=/opt/k8s-join.sh
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
EOF

# Enable the service
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable k8s-join.service
