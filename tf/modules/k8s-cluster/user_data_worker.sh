#!/bin/bash
set -e

echo "[user_data] 🚀 Starting worker setup..."

KUBERNETES_VERSION=v1.32

sudo apt-get update
sudo apt-get install -y jq unzip ebtables ethtool software-properties-common apt-transport-https ca-certificates curl gpg

curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
sudo ./aws/install

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.ipv4.ip_forward = 1
EOF
sudo sysctl --system

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

sudo systemctl enable --now crio
sudo systemctl disable --now kubelet

sudo swapoff -a
(crontab -l 2>/dev/null; echo "@reboot /sbin/swapoff -a") | crontab -

# --- Join Script ---
cat <<'EOF' | sudo tee /opt/k8s-join.sh
#!/bin/bash
set -e

echo "[k8s-join] 🔧 Running worker join script..."

if [ -f /etc/kubernetes/kubelet.conf ]; then
  echo "✅ Already joined. Skipping."
  exit 0
fi

sudo kubeadm reset -f
sudo rm -rf /etc/cni /var/lib/cni /var/lib/kubelet /etc/kubernetes

JOIN_CMD=$(aws secretsmanager get-secret-value \
  --secret-id K8S_JOIN_COMMAND \
  --region us-west-1 \
  --query SecretString \
  --output text)

if [ -z "$JOIN_CMD" ]; then
  echo "❌ Join command not found."
  exit 1
fi

FINAL_CMD="$JOIN_CMD --cri-socket unix:///var/run/crio/crio.sock"
echo "🚀 Joining with: $FINAL_CMD"
eval "$FINAL_CMD"

sudo systemctl start kubelet
EOF

sudo chmod +x /opt/k8s-join.sh

# --- systemd service ---
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

sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable k8s-join.service

# 🔁 Run join script now
sudo /opt/k8s-join.sh || true
