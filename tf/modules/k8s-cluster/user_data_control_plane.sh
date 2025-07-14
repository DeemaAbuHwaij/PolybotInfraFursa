#!/bin/bash
# PURPOSE: This script installs CRI-O, kubeadm, and Kubernetes components on the control plane instance,
# initializes the cluster, installs Flannel CNI, and uploads a permanent join command to AWS Secrets Manager.

set -e  # Exit immediately if any command fails

# Specify Kubernetes version
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

# Add Kubernetes APT key and repo
curl -fsSL https://pkgs.k8s.io/core:/stable:/$KUBERNETES_VERSION/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/$KUBERNETES_VERSION/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list

# Add CRI-O prerelease repo and key
curl -fsSL https://pkgs.k8s.io/addons:/cri-o:/prerelease:/main/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/cri-o-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/cri-o-apt-keyring.gpg] https://pkgs.k8s.io/addons:/cri-o:/prerelease:/main/deb/ /" | sudo tee /etc/apt/sources.list.d/cri-o.list

# Install CRI-O and Kubernetes tools
sudo apt-get update
sudo apt-get install -y cri-o kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

echo "🚀 Starting services..."
sudo systemctl daemon-reexec
sudo systemctl enable --now crio
sudo systemctl enable --now kubelet

echo "🛑 Disabling swap..."
sudo swapoff -a
(crontab -l 2>/dev/null; echo "@reboot /sbin/swapoff -a") | crontab -

# Check if the cluster is already initialized
if [ ! -f /etc/kubernetes/admin.conf ]; then
  echo "🚀 Initializing Kubernetes control plane..."

  # Initialize the Kubernetes cluster
  sudo kubeadm init --pod-network-cidr=10.244.0.0/16

  echo "🔧 Setting up kubeconfig..."
  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

  echo "🌐 Applying Flannel network..."
  kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml

  echo "🔐 Creating permanent kubeadm join command..."
  JOIN_CMD=$(kubeadm token create --ttl 0 --print-join-command)
  echo "$JOIN_CMD" > /tmp/k8s_join.sh

  echo "🔐 Uploading join command to AWS Secrets Manager..."
  # Upload or update the join command as a secret in AWS
  aws secretsmanager create-secret --name deema-kubeadm-join-command \
    --secret-string file:///tmp/k8s_join.sh \
    --region us-west-1 || true

  aws secretsmanager put-secret-value --secret-id deema-kubeadm-join-command \
    --secret-string file:///tmp/k8s_join.sh \
    --region us-west-1
else
  echo "✅ Kubernetes already initialized. Skipping init."
fi