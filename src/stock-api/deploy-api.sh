#!/bin/bash

set -e

echo "🚀 Déploiement de l'API Stocks..."

PROJECT_DIR="/home/azureuser/kong-stack-project-azure"
API_DIR="$PROJECT_DIR/src/stock-api"

# Installation des dépendances système
echo "📦 Installation des dépendances..."
sudo apt update
sudo apt install -y python3.11 python3.11-venv python3.11-dev python3-pip

# Création de l'utilisateur
if ! id "stockapi" &>/dev/null; then
    sudo useradd -m -s /bin/bash stockapi
    echo "✅ Utilisateur stockapi créé"
fi

# Copie du code
echo "📁 Copie du code..."
sudo mkdir -p /opt/stock-api
sudo cp -r $API_DIR/* /opt/stock-api/
sudo chown -R stockapi:stockapi /opt/stock-api

# Configuration environnement
echo "⚙️ Configuration environnement..."
sudo -u stockapi cp /opt/stock-api/.env.example /opt/stock-api/.env

# Installation Python
echo "🐍 Installation des dépendances Python..."
sudo -u stockapi python3.11 -m venv /opt/stock-api/venv
sudo -u stockapi bash -c "source /opt/stock-api/venv/bin/activate && pip install -r /opt/stock-api/requirements.txt"

# Configuration service systemd
echo "🎯 Configuration du service..."
sudo cp $PROJECT_DIR/infrastructure/api-vm/stock-api.service /etc/systemd/system/

sudo systemctl daemon-reload
sudo systemctl enable stock-api
sudo systemctl start stock-api

echo "✅ API Stocks déployée avec succès!"
echo "🌐 URL: http://$(curl -s ifconfig.me):8000"
echo "📚 Documentation: http://$(curl -s ifconfig.me):8000/docs/swagger"
