#!/bin/bash
set -e

# Only initialize if not already initialized
if [ ! -f /etc/kubernetes/admin.conf ]; then
  echo "🚀 Initializing Kubernetes control plane..."

  kubeadm init --pod-network-cidr=10.244.0.0/16

  mkdir -p $HOME/.kube
  cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  chown $(id -u):$(id -g) $HOME/.kube/config

  echo "🌐 Installing Flannel network plugin..."
  kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml

  echo "✅ Control plane initialization completed."
else
  echo "⚠️ Control plane already initialized. Skipping..."
fi
