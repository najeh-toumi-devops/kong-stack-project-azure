#!/bin/bash

set -e

echo "🔧 CONFIGURATION COMPLÈTE POUR LE PORT 8000"

APP_DIR="/opt/stock-api"

# Arrêter les services
echo "1. 🛑 Arrêt des services..."
sudo systemctl stop stock-api || true
sudo systemctl stop nginx || true

# 1. Mettre à jour le .env pour le port 8001
echo "2. ⚙️ Mise à jour de la configuration..."
sudo -u stockapi tee $APP_DIR/.env > /dev/null << 'EOF'
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
API_PORT=8001
CACHE_ENABLED=true
CACHE_TTL=300
LOG_LEVEL=INFO
EOF

# 2. Corriger app/__init__.py
echo "3. 📁 Correction de app/__init__.py..."
sudo tee $APP_DIR/app/__init__.py > /dev/null << 'EOF'
from flask import Flask, jsonify
from flask_cors import CORS
from flasgger import Swagger
import os

def create_app():
    app = Flask(__name__)
    
    # Configuration
    app.config['SECRET_KEY'] = os.getenv('SECRET_KEY', 'dev-key-2024')
    
    # Configuration Swagger
    app.config['SWAGGER'] = {
        'title': 'Stock API Documentation',
        'uiversion': 3,
        'specs_route': '/swagger/'
    }
    
    # Initialiser les extensions
    CORS(app)
    Swagger(app)
    
    # Importer et enregistrer les blueprints
    from app.routes.stocks import stocks_bp
    
    # Enregistrer le blueprint
    app.register_blueprint(stocks_bp, url_prefix='/api/v1')
    
    # Route racine
    @app.route('/')
    def home():
        return jsonify({
            'message': 'Stock API Service',
            'version': '1.0.0',
            'status': 'running',
            'endpoints': {
                'health': '/api/v1/health',
                'stocks': '/api/v1/stocks',
                'documentation': '/swagger/'
            }
        })
    
    # Route health directe
    @app.route('/health')
    def health_direct():
        from datetime import datetime
        return jsonify({
            'status': 'healthy',
            'timestamp': datetime.utcnow().isoformat(),
            'service': 'stock-api',
            'version': '1.0.0'
        })
    
    return app
EOF

# 3. Corriger app/routes/stocks.py
echo "4. 🛣️ Correction des routes..."
sudo tee $APP_DIR/app/routes/stocks.py > /dev/null << 'EOF'
from flask import Blueprint, jsonify
from flasgger import swag_from
from datetime import datetime

# Créer le blueprint
stocks_bp = Blueprint('stocks', __name__)

@stocks_bp.route('/health', methods=['GET'])
@swag_from({
    'responses': {
        200: {
            'description': 'Health check successful',
            'schema': {
                'type': 'object',
                'properties': {
                    'status': {'type': 'string'},
                    'timestamp': {'type': 'string'},
                    'service': {'type': 'string'},
                    'version': {'type': 'string'}
                }
            }
        }
    }
})
def health_check():
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.utcnow().isoformat(),
        'service': 'stock-api',
        'version': '1.0.0'
    })

@stocks_bp.route('/stocks', methods=['GET'])
@swag_from({
    'responses': {
        200: {
            'description': 'List of stocks',
            'schema': {
                'type': 'object',
                'properties': {
                    'stocks': {
                        'type': 'array',
                        'items': {
                            'type': 'object',
                            'properties': {
                                'symbol': {'type': 'string'},
                                'name': {'type': 'string'},
                                'price': {'type': 'number'},
                                'currency': {'type': 'string'}
                            }
                        }
                    },
                    'count': {'type': 'integer'},
                    'source': {'type': 'string'}
                }
            }
        }
    }
})
def get_stocks():
    # Données mock pour tester
    mock_stocks = [
        {'symbol': 'AAPL', 'name': 'Apple Inc.', 'price': 150.25, 'currency': 'USD'},
        {'symbol': 'GOOGL', 'name': 'Alphabet Inc.', 'price': 2750.80, 'currency': 'USD'},
        {'symbol': 'MSFT', 'name': 'Microsoft Corporation', 'price': 305.45, 'currency': 'USD'},
        {'symbol': 'AMZN', 'name': 'Amazon.com Inc.', 'price': 3320.50, 'currency': 'USD'},
        {'symbol': 'TSLA', 'name': 'Tesla Inc.', 'price': 850.75, 'currency': 'USD'}
    ]
    
    return jsonify({
        'stocks': mock_stocks,
        'count': len(mock_stocks),
        'source': 'mock'
    })

@stocks_bp.route('/stocks/<symbol>', methods=['GET'])
def get_stock(symbol):
    mock_stocks = [
        {'symbol': 'AAPL', 'name': 'Apple Inc.', 'price': 150.25, 'currency': 'USD'},
        {'symbol': 'GOOGL', 'name': 'Alphabet Inc.', 'price': 2750.80, 'currency': 'USD'},
        {'symbol': 'MSFT', 'name': 'Microsoft Corporation', 'price': 305.45, 'currency': 'USD'}
    ]
    
    stock = next((s for s in mock_stocks if s['symbol'].upper() == symbol.upper()), None)
    
    if stock:
        return jsonify({'stock': stock})
    else:
        return jsonify({'error': 'Stock not found'}), 404
EOF

# 4. Configuration NGINX pour le port 8000
echo "5. 🌐 Configuration de NGINX pour le port 8000..."
sudo tee /etc/nginx/sites-available/stock-api > /dev/null << 'EOF'
server {
    listen 8000;
    server_name localhost;
    client_max_body_size 10M;

    # Root endpoint
    location = / {
        proxy_pass http://127.0.0.1:8001/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # API routes
    location /api/ {
        proxy_pass http://127.0.0.1:8001/api/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Swagger UI
    location /swagger/ {
        proxy_pass http://127.0.0.1:8001/swagger/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Health check direct
    location /health {
        proxy_pass http://127.0.0.1:8001/health;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Fallback for other routes
    location / {
        proxy_pass http://127.0.0.1:8001/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

# Activer la configuration NGINX
sudo ln -sf /etc/nginx/sites-available/stock-api /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

# 5. Mettre à jour le service systemd
echo "6. 🔧 Mise à jour du service systemd..."
sudo tee /etc/systemd/system/stock-api.service > /dev/null << EOF
[Unit]
Description=Stock API Service with Gunicorn
After=network.target mongod.service redis-server.service
Requires=mongod.service redis-server.service

[Service]
Type=simple
User=stockapi
Group=stockapi
WorkingDirectory=$APP_DIR
Environment=PATH=$APP_DIR/venv/bin:/usr/local/bin:/usr/bin:/bin
ExecStart=$APP_DIR/venv/bin/gunicorn --bind 0.0.0.0:8001 --workers 1 --timeout 30 --access-logfile - --error-logfile - run:app
ExecReload=/bin/kill -s HUP \$MAINPID
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# 6. Redémarrer les services
echo "7. 🔄 Redémarrage des services..."
sudo systemctl daemon-reload
sudo systemctl start stock-api

# Tester NGINX
sudo nginx -t
sudo systemctl start nginx

# 7. Vérifications
echo "8. ✅ Vérifications..."
sleep 5

echo "Test sur le port 8000 (via NGINX):"
curl -s http://localhost:8000/ | python3 -m json.tool 2>/dev/null || curl -s http://localhost:8000/

echo ""
echo "Test /api/v1/health:"
curl -s http://localhost:8000/api/v1/health | python3 -m json.tool 2>/dev/null || curl -s http://localhost:8000/api/v1/health

echo ""
echo "Test /api/v1/stocks:"
curl -s http://localhost:8000/api/v1/stocks | python3 -m json.tool 2>/dev/null || curl -s http://localhost:8000/api/v1/stocks

echo ""
echo "Test direct sur le port 8001:"
curl -s http://localhost:8001/api/v1/health | python3 -m json.tool 2>/dev/null || curl -s http://localhost:8001/api/v1/health

echo ""
echo "🎯 Configuration terminée:"
echo "   🌐 Public: http://localhost:8000 (NGINX)"
echo "   🔧 Interne: http://localhost:8001 (Gunicorn)"
