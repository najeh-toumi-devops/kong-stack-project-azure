#!/bin/bash

echo "🔴 Installation de Redis..."
sudo apt install -y redis-server

# Configuration Redis
sudo sed -i 's/bind 127.0.0.1 ::1/bind 0.0.0.0/' /etc/redis/redis.conf
sudo sed -i 's/protected-mode yes/protected-mode no/' /etc/redis/redis.conf
sudo sed -i 's/# requirepass foobared/requirepass redis2025/' /etc/redis/redis.conf

# Configuration cache
sudo tee -a /etc/redis/redis.conf << 'EOF'
maxmemory 256mb
maxmemory-policy allkeys-lru
save 900 1
save 300 10
save 60 10000
EOF

sudo systemctl restart redis-server
sudo systemctl enable redis-server

echo "✅ Redis installé"
