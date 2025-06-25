#!/bin/bash
set -e

# These instructions are for Kubernetes v1.32
KUBERNETES_VERSION=v1.32

# Install base tools
apt-get update
apt-get install jq unzip ebtables ethtool -y

# Install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install

# Enable IPv4 forwarding
cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.ipv4.ip_forward = 1
EOF
sysctl --system

# Add Kubernetes and CRI-O repositories
curl -fsSL https://pkgs.k8s.io/core:/stable:/$KUBERNETES_VERSION/deb/Release.key | \
    gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/$KUBERNETES_VERSION/deb/ /" | \
    tee /etc/apt/sources.list.d/kubernetes.list

curl -fsSL https://pkgs.k8s.io/addons:/cri-o:/prerelease:/main/deb/Release.key | \
    gpg --dearmor -o /etc/apt/keyrings/cri-o-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/cri-o-apt-keyring.gpg] https://pkgs.k8s.io/addons:/cri-o:/prerelease:/main/deb/ /" | \
    tee /etc/apt/sources.list.d/cri-o.list

apt-get update
apt-get install -y software-properties-common apt-transport-https ca-certificates curl gpg
apt-get install -y cri-o kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

# Start CRI-O and kubelet
systemctl enable --now crio
systemctl enable --now kubelet

# Disable swap memory
swapoff -a
(crontab -l 2>/dev/null; echo "@reboot /sbin/swapoff -a") | crontab -

# ---------------------------------------------------------
# DYNAMIC KUBEADM JOIN SECTION
# ---------------------------------------------------------

cat <<'EOF' > /opt/k8s-join.sh
#!/bin/bash
set -e

# Skip if already joined
if [ -f /etc/kubernetes/kubelet.conf ]; then
  echo "[k8s-join] Node already joined. Skipping."
  exit 0
fi

echo "[k8s-join] Fetching join command from AWS Secrets Manager..."
JOIN_CMD=$(aws secretsmanager get-secret-value \
  --secret-id kubeadm-join-command \
  --region us-west-1 \
  --query SecretString \
  --output text)

if [ -z "$JOIN_CMD" ]; then
  echo "[k8s-join] Failed to retrieve join command."
  exit 1
fi

echo "[k8s-join] Executing join command..."
eval "$JOIN_CMD"
EOF

chmod +x /opt/k8s-join.sh

# Create systemd service
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

# Enable the join service
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable k8s-join.service
