#!/bin/bash
# PURPOSE: Install CRI-O + Kubernetes on the control plane, apply Flannel, and store join token in AWS Secrets Manager.

set -e  # Exit on any error

KUBERNETES_VERSION=v1.32
AWS_REGION=us-west-1
SECRET_NAME=deema-kubeadm-join-command

echo "🧩 Installing base dependencies..."
sudo apt-get update
sudo apt-get install -y jq unzip ebtables ethtool software-properties-common apt-transport-https ca-certificates curl gpg

echo "🔐 Installing AWS CLI..."
curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
sudo ./aws/install --update

echo "📡 Enabling IPv4 forwarding..."
echo 'net.ipv4.ip_forward = 1' | sudo tee /etc/sysctl.d/k8s.conf
sudo sysctl --system

echo "📦 Adding APT keyrings and repositories..."
sudo mkdir -p /etc/apt/keyrings

# Kubernetes
curl -fsSL https://pkgs.k8s.io/core:/stable:/$KUBERNETES_VERSION/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/$KUBERNETES_VERSION/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list

# CRI-O
curl -fsSL https://pkgs.k8s.io/addons:/cri-o:/prerelease:/main/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/cri-o-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/cri-o-apt-keyring.gpg] https://pkgs.k8s.io/addons:/cri-o:/prerelease:/main/deb/ /" | sudo tee /etc/apt/sources.list.d/cri-o.list

echo "📦 Installing CRI-O and Kubernetes components..."
sudo apt-get update
sudo apt-get install -y cri-o kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

echo "🚀 Enabling system services..."
sudo systemctl daemon-reexec
sudo systemctl enable --now crio
sudo systemctl enable --now kubelet

echo "🛑 Disabling swap..."
sudo swapoff -a
(crontab -l 2>/dev/null; echo "@reboot /sbin/swapoff -a") | crontab -

if [ ! -f /etc/kubernetes/admin.conf ]; then
  echo "🚀 Initializing Kubernetes control plane..."
  sudo kubeadm init --pod-network-cidr=10.244.0.0/16

  echo "🔧 Configuring kubeconfig..."
  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

  echo "🌐 Applying Flannel CNI..."
  kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml

  echo "🔑 Creating permanent kubeadm join command..."
  JOIN_CMD=$(kubeadm token create --ttl 0 --print-join-command)
  echo "$JOIN_CMD" > /tmp/k8s_join.sh

  echo "🔐 Uploading join command to AWS Secrets Manager..."
  aws secretsmanager create-secret --name "$SECRET_NAME" \
    --secret-string file:///tmp/k8s_join.sh \
    --region "$AWS_REGION" || true

  aws secretsmanager put-secret-value \
    --secret-id "$SECRET_NAME" \
    --secret-string file:///tmp/k8s_join.sh \
    --region "$AWS_REGION"

  echo "✅ Join command uploaded to AWS Secrets Manager."
else
  echo "✅ Kubernetes already initialized. Skipping init."
fi
