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

  echo "🔐 Creating permanent kubeadm join token..."
  JOIN_CMD=$(sudo kubeadm token create --ttl 0 --print-join-command)

  echo "🔑 Storing join command in AWS Secrets Manager..."
  aws secretsmanager put-secret-value \
    --secret-id kubeadm-join-command \
    --secret-string "$JOIN_CMD" \
    --region us-west-1


  echo "✅ Control plane initialization and join command storage completed."
else
  echo "⚠️ Control plane already initialized. Skipping..."
fi


