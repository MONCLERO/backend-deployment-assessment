#!/bin/bash

set -euo pipefail

echo "Updating system packages..."
sudo yum update -y

echo "Adding MongoDB 7.0 repository..."

sudo cat <<'EOF' > /etc/yum.repos.d/mongodb-org-7.0.repo
[mongodb-org-7.0]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/amazon/2/mongodb-org/7.0/x86_64/
gpgcheck=1
enabled=1
gpgkey=https://pgp.mongodb.com/server-7.0.asc
EOF

echo "Refreshing package metadata..."
yum makecache

echo "Installing MongoDB Community Edition..."
sudo yum install -y mongodb-org

echo "Enabling and starting MongoDB..."
sudo systemctl enable mongod
sudo systemctl start mongod

echo "Checking MongoDB service..."
sudo systemctl status mongod --no-pager

echo "Checking MongoDB version..."
mongod --version

echo "MongoDB installation completed successfully!"
