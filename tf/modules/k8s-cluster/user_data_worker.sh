#!/bin/bash

REGION="us-west-1"
SECRET_ID="deema-kubeadm-join-command"

# Add CRI-O repo
curl -fsSL https://pkgs.k8s.io/addons:/cri-o:/prerelease:/main/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/cri-o-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/cri-o-apt-keyring.gpg] https://pkgs.k8s.io/addons:/cri-o:/prerelease:/main/deb/ /" | sudo tee /etc/apt/sources.list.d/cri-o.list

echo "📦 Installing CRI-O and Kubernetes components..."
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

echo "🔑 Fetching kubeadm join command from AWS Secrets Manager..."
for attempt in {1..10}; do
  JOIN_COMMAND=$(aws secretsmanager get-secret-value \
    --region "$REGION" \
    --secret-id "$SECRET_ID" \
    --query SecretString \
    --output text 2>/dev/null) && break

  echo "⏳ [$attempt] Secret not found yet. Retrying in 15s..."
  sleep 15
done

if [ -z "$JOIN_COMMAND" ]; then
  echo "❌ Failed to fetch join command. Exiting."
  exit 1
fi

echo "🤝 Joining the Kubernetes cluster..."
eval "$JOIN_COMMAND"
