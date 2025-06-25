#!/bin/bash
set -e

# These instructions are for Kubernetes v1.32
KUBERNETES_VERSION=v1.32

echo "🛠️ Installing dependencies..."
sudo apt-get update
sudo apt-get install -y jq unzip ebtables ethtool

# Install AWS CLI
echo "☁️ Installing AWS CLI..."
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
sudo ./aws/install

# Enable IPv4 forwarding
echo "🔧 Enabling IPv4 forwarding..."
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.ipv4.ip_forward = 1
EOF

sudo sysctl --system

# Add CRI-O and Kubernetes repositories
echo "📦 Adding Kubernetes and CRI-O repositories..."
sudo mkdir -p /etc/apt/keyrings

curl -fsSL https://pkgs.k8s.io/core:/stable:/$KUBERNETES_VERSION/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/$KUBERNETES_VERSION/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list

curl -fsSL https://pkgs.k8s.io/addons:/cri-o:/prerelease:/main/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/cri-o-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/cri-o-apt-keyring.gpg] https://pkgs.k8s.io/addons:/cri-o:/prerelease:/main/deb/ /" | sudo tee /etc/apt/sources.list.d/cri-o.list

sudo apt-get update
sudo apt-get install -y software-properties-common apt-transport-https ca-certificates curl gpg
sudo apt-get install -y cri-o kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

# Start services
sudo systemctl start crio
sudo systemctl enable crio
sudo systemctl enable kubelet

# Disable swap permanently
echo "🚫 Disabling swap..."
swapoff -a
(crontab -l ; echo "@reboot /sbin/swapoff -a") | crontab -

# Initialize the control plane if not already initialized
if [ ! -f /etc/kubernetes/admin.conf ]; then
  echo "🚀 Initializing Kubernetes control plane..."

  sudo kubeadm init --pod-network-cidr=10.244.0.0/16

  echo "🔧 Setting up kubeconfig for the current user..."
  export HOME=/root
  mkdir -p $HOME/.kube
  cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  chown $(id -u):$(id -g) $HOME/.kube/config

  echo "🌐 Installing Flannel network plugin..."
  kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml

  echo "🔐 Creating permanent kubeadm join token..."
  JOIN_CMD=$(kubeadm token create --ttl 0 --print-join-command \
    | awk '{print $0, "--discovery-token-ca-cert-hash", $(NF-1), $NF}' | sed 's/--discovery-token-ca-cert-hash/--discovery-token-ca-cert-hash=/')

  echo "🔑 Storing join command in AWS Secrets Manager..."
  aws secretsmanager put-secret-value \
    --region us-west-1 \
    --secret-id deema-kubeadm-join-command \
    --secret-string "$JOIN_CMD"
fi
