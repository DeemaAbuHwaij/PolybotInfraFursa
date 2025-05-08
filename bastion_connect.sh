#!/bin/bash

# Check if the SSH key path environment variable is set
if [ -z "$KEY_PATH" ]; then
  echo "❌ Error: KEY_PATH environment variable not set."
  echo "Please run: export KEY_PATH=/path/to/your/key.pem"
  exit 5
fi

# Bastion and target instance details (hardcoded)
BASTION_USER=ubuntu
BASTION_IP=18.144.5.190            # Bastion public IP
TARGET_USER=ubuntu
TARGET_PRIVATE_IP=10.0.0.50      # Polybot private IP

# SSH into the target instance via the Bastion host
ssh -i "$KEY_PATH" -o ProxyCommand="ssh -i $KEY_PATH -W %h:%p $BASTION_USER@$BASTION_IP" $TARGET_USER@$TARGET_PRIVATE_IP


