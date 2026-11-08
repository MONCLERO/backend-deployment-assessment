#!/bin/bash

set -euo pipefail

echo "Updating system packages..."
sudo yum update -y

echo "Installing Docker..."
amazon-linux-extras install docker -y

echo "Enabling and starting Docker..."
sudo systemctl enable docker
sudo systemctl start docker

echo "Verifying Docker installation..."
docker --version

echo "Creating Docker CLI plugins directory..."
sudo mkdir -p /usr/local/lib/docker/cli-plugins

echo "Installing Docker Compose..."

sudo curl -SL \
  https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 \
  -o /usr/local/lib/docker/cli-plugins/docker-compose

sudo chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

echo "Verifying Docker Compose..."
docker compose version

echo "Backend host setup completed successfully!"