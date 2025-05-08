#!/bin/bash

# Validate that KEY_PATH is set
if [ -z "$KEY_PATH" ]; then
  echo "KEY_PATH env var is expected"
  exit 5
fi

# Validate that all three arguments are provided
if [ $# -lt 3 ]; then
  echo "Usage: $0 <bastion_ip> <target_private_ip> <command>"
  exit 5
fi

BASTION_IP="$1"               # Not used on the bastion itself, but required by test
TARGET_PRIVATE_IP="$2"
COMMAND="$3"

# Connect from bastion to private instance
ssh -i "$KEY_PATH" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ubuntu@$TARGET_PRIVATE_IP "$COMMAND"
