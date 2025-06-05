#!/bin/bash

# Stop and remove existing container if running
sudo docker stop mynginx || true
sudo docker rm mynginx || true

# Ensure config and certs directories exist
mkdir -p /home/ubuntu/conf.d
mkdir -p /home/ubuntu/certs

# Run the Nginx container with volumes
sudo docker run -d --name mynginx \
  -p 443:443 \
  -v /home/ubuntu/conf.d:/etc/nginx/conf.d/ \
  -v /home/ubuntu/certs:/etc/nginx/certs/ \
  nginx
