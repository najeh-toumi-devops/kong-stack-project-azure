#!/bin/bash

echo "🔧 Correction des permissions..."

# Arrêter le service
sudo systemctl stop stock-api 2>/dev/null || true

# Donner tous les droits à stockapi sur /opt/stock-api
sudo chown -R stockapi:stockapi /opt/stock-api
sudo chmod -R 755 /opt/stock-api

# S'assurer que .env existe et a les bonnes permissions
if [ ! -f "/opt/stock-api/.env" ]; then
    echo "Création de .env..."
    sudo -u stockapi cp /opt/stock-api/.env.example /opt/stock-api/.env 2>/dev/null || {
        echo "Création manuelle de .env..."
        sudo -u stockapi cat > /opt/stock-api/.env << 'EOF'
# Configuration MongoDB
MONGODB_URI=mongodb://stockadmin:mongodb2025@localhost:27017/stock_management?authSource=admin
MONGODB_DB=stock_management

# Configuration Redis
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD=redis2025
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
EOF
    }
fi

# Vérifier les permissions
echo "Permissions actuelles:"
sudo -u stockapi ls -la /opt/stock-api/.env

# Redémarrer le service
sudo systemctl start stock-api

echo "✅ Permissions corrigées"
