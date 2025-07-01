#!/bin/bash
# PURPOSE: This script initializes the Kubernetes control plane using kubeadm (only if not already initialized),
# sets up kubectl access, and installs the Calico CNI.

set -e  # Exit immediately if a command fails

echo "[INIT] 🧠 Starting kubeadm control plane init..."

# Only initialize the cluster if it hasn't been initialized already
if [ ! -f /etc/kubernetes/admin.conf ]; then
    echo "[INIT] 🚀 Running kubeadm init..."

    # Initialize Kubernetes control plane with specified pod network CIDR and CRI socket (for CRI-O)
    sudo kubeadm init --pod-network-cidr=192.168.0.0/16 --cri-socket=unix:///var/run/crio/crio.sock

    echo "[INIT] 🔐 Setting up kubeconfig for ubuntu user"

    # Set HOME explicitly for the 'ubuntu' user
    export HOME=/home/ubuntu

    # Create .kube directory and copy admin config so kubectl can work
    mkdir -p $HOME/.kube
    sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
    sudo chown $(id -u):$(id -g) $HOME/.kube/config

    echo "[INIT] 🌐 Installing Calico CNI"

    # Install Calico as the CNI plugin for pod networking
    kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.2/manifests/calico.yaml
else
    echo "[INIT] ✅ Kubernetes already initialized. Skipping."
fi
