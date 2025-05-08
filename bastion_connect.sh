#!/bin/bash

if [ -z "$KEY_PATH" ]; then
  echo "KEY_PATH env var is expected"
  exit 5
fi

if [ -z "$1" ]; then
  echo "Please provide bastion IP address"
  exit 5
fi

if [ -z "$2" ]; then
  echo "Please provide private IP of the target instance"
  exit 5
fi

if [ $# -lt 3 ]; then
  echo "Please provide a command to run on the target"
  exit 5
fi

BASTION_IP="$1"
TARGET_PRIVATE_IP="$2"
shift 2

ssh -i "$KEY_PATH" -o StrictHostKeyChecking=no \
  -o ProxyCommand="ssh -i $KEY_PATH -o StrictHostKeyChecking=no -W %h:%p ubuntu@$BASTION_IP" \
  ubuntu@"$TARGET_PRIVATE_IP" "$@"
