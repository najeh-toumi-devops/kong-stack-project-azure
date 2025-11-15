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
cd /opt/stock-api

# Créer le fichier .env depuis .env.example si .env n'existe pas
if [ ! -f .env ]; then
    if [ -f .env.example ]; then
        sudo -u stockapi cp .env.example .env
        echo "✅ Fichier .env créé depuis .env.example"
    else
        echo "⚠️  .env.example non trouvé, création d'un .env par défaut"
        sudo -u stockapi cat > .env << 'ENVFILE'
# Configuration MongoDB
MONGODB_URI=mongodb://stockadmin:xxxxxxxxxxxx@localhost:27017/stock_management?authSource=admin
MONGODB_DB=stock_management

# Configuration Redis
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD=xxxxxxxx
REDIS_DB=0
REDIS_TTL=3600

# Configuration Flask
FLASK_ENV=production
SECRET_KEY=dev-secret-key-change-in-production
JWT_SECRET_KEY=jwt-secret-key-change-in-production

# Configuration API
API_HOST=0.0.0.0
API_PORT=8000

# Configuration Cache
CACHE_ENABLED=true
CACHE_TTL=300

# Logging
LOG_LEVEL=INFO
ENVFILE
    fi
fi

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

# Attendre un peu et vérifier le statut
sleep 3
echo "🔍 Vérification du service..."
sudo systemctl status stock-api --no-pager

echo "✅ API Stocks déployée avec succès!"
echo "🌐 URL: http://$(curl -s ifconfig.me):8000"
echo "📚 Documentation: http://$(curl -s ifconfig.me):8000/docs/swagger"
