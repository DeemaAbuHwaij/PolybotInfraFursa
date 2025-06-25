#!/bin/bash
set -e

# Only initialize if not already initialized
if [ ! -f /etc/kubernetes/admin.conf ]; then
  echo "🚀 Initializing Kubernetes control plane..."

  sudo kubeadm init --pod-network-cidr=10.244.0.0/16

  echo "🔧 Setting up kubeconfig for the current user..."
  export HOME=/home/ubuntu
  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

  echo "🌐 Installing Flannel network plugin..."
  kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
else
  echo "⚠️ Control plane already initialized. Skipping kubeadm init..."
fi

echo "🔐 Generating permanent kubeadm join token..."
JOIN_CMD=$(echo "sudo $(kubeadm token create --ttl 0 --print-join-command)")
echo "$JOIN_CMD" > /tmp/k8s_join.sh

echo "🧪 Verifying AWS CLI..."
if ! command -v aws &> /dev/null; then
  echo "🌍 Installing AWS CLI..."
  curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
  unzip -q awscliv2.zip
  sudo ./aws/install
fi

echo "🔑 Updating join command in AWS Secrets Manager..."
aws secretsmanager put-secret-value \
  --secret-id K8S_JOIN_COMMAND \
  --secret-string file:///tmp/k8s_join.sh \
  --region us-west-1

echo "✅ Join command stored successfully in secret K8S_JOIN_COMMAND (us-west-1)"
