#!/bin/bash

# This script sets up an NGINX Ingress Controller on the control plane node

echo "[INFO] Deploying NGINX Ingress Controller..."

# Create namespace for ingress if not exists
kubectl get ns ingress-nginx >/dev/null 2>&1 || kubectl create ns ingress-nginx

# Apply official NGINX ingress controller manifests
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.9.5/deploy/static/provider/cloud/deploy.yaml

# Wait for the ingress controller pods to be ready
echo "[INFO] Waiting for ingress controller to be ready..."
kubectl wait --namespace ingress-nginx   --for=condition=Ready pod   --selector=app.kubernetes.io/component=controller   --timeout=300s

echo "[INFO] NGINX Ingress Controller deployed successfully!"