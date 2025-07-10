#!/bin/bash
set -e

echo "📦 Starting control-plane initialization..."

# Only initialize if not already done
if [ ! -f /etc/kubernetes/admin.conf ]; then
  echo "🔧 Initializing Kubernetes cluster..."
  sudo /usr/bin/kubeadm init --pod-network-cidr=10.244.0.0/16 | tee /tmp/kubeadm-init.log
fi

# Configure kubectl for current user (assumes running as ubuntu)
mkdir -p $HOME/.kube
sudo cp -f /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Install Flannel if not already installed
if ! kubectl get pods -n kube-flannel &> /dev/null; then
  echo "🌐 Installing Flannel CNI..."
  kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml
fi

# Wait for API server to be ready
echo "⏳ Waiting for Kubernetes API server to be ready..."
for i in {1..30}; do
  if kubectl get nodes &> /dev/null; then
    echo "✅ API server is up."
    break
  else
    echo "Waiting for API server... ($i/30)"
    sleep 5
  fi
done

# Generate the join command
echo "🔑 Generating kubeadm join command..."
JOIN_COMMAND=$(kubeadm token create --print-join-command --ttl 24h)

# Save the join command to a temp file
echo "sudo $JOIN_COMMAND" > /tmp/k8s_join.sh

# Store in AWS Secrets Manager
echo "🔐 Saving join command in AWS Secrets Manager..."
aws secretsmanager put-secret-value \
  --secret-id deema-kubeadm-join-command \
  --secret-string file:///tmp/k8s_join.sh \
  --region us-west-1

echo "✅ Join command saved to Secrets Manager."
