#!/bin/bash

echo "🟢 Installation de MongoDB..."
sudo apt update && sudo apt upgrade -y

# Installation MongoDB
wget -qO - https://www.mongodb.org/static/pgp/server-6.0.asc | sudo apt-key add -
echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/6.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-6.0.list

sudo apt update
sudo apt install -y mongodb-org

# Configuration MongoDB
sudo systemctl start mongod
sudo systemctl enable mongod

# Configuration pour accepter les connexions distantes
sudo sed -i 's/bindIp: 127.0.0.1/bindIp: 0.0.0.0/' /etc/mongod.conf

# Création utilisateur admin
mongosh admin --eval '
db.createUser({
  user: "stockadmin",
  pwd: "xxxxxxxxxxx",
  roles: [ { role: "root", db: "admin" } ]
})'

sudo systemctl restart mongod
echo "✅ MongoDB installé"
