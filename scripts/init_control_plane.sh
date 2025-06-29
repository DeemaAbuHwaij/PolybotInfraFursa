#!/bin/bash
set -e

echo "[INIT] 🧠 Starting kubeadm control plane init..."

# Only run if kubeadm hasn't already been initialized
if [ ! -f /etc/kubernetes/admin.conf ]; then
    echo "[INIT] 🚀 Running kubeadm init..."
    sudo kubeadm init --pod-network-cidr=192.168.0.0/16 --cri-socket=unix:///var/run/crio/crio.sock

    echo "[INIT] 🔐 Setting up kubeconfig for ubuntu user"
    export HOME=/home/ubuntu
    mkdir -p $HOME/.kube
    sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
    sudo chown $(id -u):$(id -g) $HOME/.kube/config

    echo "[INIT] 🌐 Installing Calico CNI"
    kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.2/manifests/calico.yaml
else
    echo "[INIT] ✅ Kubernetes already initialized. Skipping."
fi
