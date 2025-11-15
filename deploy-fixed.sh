#!/bin/bash

set -e

echo "🚀 DÉPLOIEMENT DE LA VERSION CORRIGÉE"

REPO_DIR="/home/azureuser/kong-stack-project-azure/src/stock-api"
APP_DIR="/opt/stock-api"

# Arrêter le service
sudo systemctl stop stock-api

# Copier la version corrigée
echo "📦 Copie des fichiers corrigés..."
sudo rm -rf $APP_DIR/*
sudo cp -r $REPO_DIR/* $APP_DIR/
sudo chown -R stockapi:stockapi $APP_DIR

# S'assurer que .env existe
if [ ! -f "$APP_DIR/.env" ]; then
    echo "⚙️ Création du fichier .env..."
    sudo -u stockapi cp $APP_DIR/.env.example $APP_DIR/.env 2>/dev/null || sudo tee $APP_DIR/.env > /dev/null << 'EOF'
MONGODB_URI=mongodb://stockadmin:mongodb2025@localhost:27017/stock_management?authSource=admin
MONGODB_DB=stock_management
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD=redis2025
REDIS_DB=0
FLASK_ENV=production
SECRET_KEY=dev-key-2024
JWT_SECRET_KEY=jwt-key-2024
API_HOST=0.0.0.0
API_PORT=8000
CACHE_ENABLED=true
CACHE_TTL=300
LOG_LEVEL=INFO
EOF
fi

# Redémarrer
echo "🔧 Redémarrage du service..."
sudo systemctl daemon-reload
sudo systemctl start stock-api

# Test
echo "🧪 Test de l'API..."
sleep 5

echo "Test / :"
curl -s http://localhost:8000/ | python3 -m json.tool || curl -s http://localhost:8000/

echo "Test /api/v1/health :"
curl -s http://localhost:8000/api/v1/health | python3 -m json.tool || curl -s http://localhost:8000/api/v1/health

echo "Test /api/v1/stocks :"
curl -s http://localhost:8000/api/v1/stocks | python3 -m json.tool || curl -s http://localhost:8000/api/v1/stocks

echo "✅ Déploiement terminé"
