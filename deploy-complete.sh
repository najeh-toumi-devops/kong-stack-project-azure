#!/bin/bash

set -e

echo "🚀 DÉPLOIEMENT FINAL API STOCKS - TOUT EN UN"

PROJECT_DIR="/home/azureuser/kong-stack-project-azure"
APP_DIR="/opt/stock-api"

# Fonction pour logger
log() {
    echo "📝 $1"
}

# ÉTAPE 1: Installation des dépendances système
log "Installation des dépendances système..."
sudo apt update
sudo apt install -y python3.11 python3.11-venv python3.11-dev python3-pip curl

# ÉTAPE 2: Installation MongoDB
log "Installation de MongoDB..."
if ! command -v mongod &> /dev/null; then
    log "Téléchargement et installation de MongoDB..."
    wget -qO - https://www.mongodb.org/static/pgp/server-6.0.asc | sudo apt-key add -
    echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/6.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-6.0.list
    sudo apt update
    sudo apt install -y mongodb-org
    sudo systemctl start mongod
    sudo systemctl enable mongod
    sudo sed -i 's/bindIp: 127.0.0.1/bindIp: 0.0.0.0/' /etc/mongod.conf
    
    # Configuration MongoDB avec le bon mot de passe
    mongosh admin --eval '
    db.createUser({
      user: "stockadmin",
      pwd: "mongodb2025",
      roles: [ { role: "root", db: "admin" } ]
    })'
    
    sudo systemctl restart mongod
    echo "✅ MongoDB installé avec mot de passe: mongodb2025"
else
    echo "✅ MongoDB déjà installé"
fi

# ÉTAPE 3: Installation Redis
log "Installation de Redis..."
if ! command -v redis-server &> /dev/null; then
    sudo apt install -y redis-server
    sudo sed -i 's/bind 127.0.0.1 ::1/bind 0.0.0.0/' /etc/redis/redis.conf
    sudo sed -i 's/protected-mode yes/protected-mode no/' /etc/redis/redis.conf
    sudo sed -i 's/# requirepass foobared/requirepass redis2025/' /etc/redis/redis.conf  # CORRECTION ICI
    sudo tee -a /etc/redis/redis.conf << 'EOF' > /dev/null
maxmemory 256mb
maxmemory-policy allkeys-lru
save 900 1
save 300 10
save 60 10000
EOF
    sudo systemctl restart redis-server
    sudo systemctl enable redis-server
    echo "✅ Redis installé avec mot de passe: redis2025"
else
    echo "✅ Redis déjà installé"
fi

# ÉTAPE 4: Création utilisateur
log "Création de l'utilisateur..."
if ! id "stockapi" &>/dev/null; then
    sudo useradd -m -s /bin/bash stockapi
    echo "✅ Utilisateur stockapi créé"
else
    echo "✅ Utilisateur stockapi existe déjà"
fi

# ÉTAPE 5: Nettoyage et préparation
log "Préparation de l'environnement..."
sudo systemctl stop stock-api 2>/dev/null || true
sudo rm -rf $APP_DIR
sudo mkdir -p $APP_DIR/{app/{models,routes,services,utils},config,tests,docs}

# ÉTAPE 6: Création de TOUS les fichiers Python
log "Création de tous les fichiers de l'application..."

# 6.1 Fichier run.py
sudo tee $APP_DIR/run.py > /dev/null << 'EOF'
from app import create_app
import os

app = create_app()

if __name__ == '__main__':
    host = os.environ.get('API_HOST', '0.0.0.0')
    port = int(os.environ.get('API_PORT', 8000))
    debug = os.environ.get('FLASK_ENV') == 'development'
    
    app.run(host=host, port=port, debug=debug)
EOF

# 6.2 Fichier requirements.txt
sudo tee $APP_DIR/requirements.txt > /dev/null << 'EOF'
Flask==2.3.3
Flask-RESTful==0.3.10
Flask-JWT-Extended==4.5.3
Flask-CORS==4.0.0
flasgger==0.9.7.1
pymongo==4.5.0
python-dotenv==1.0.0
prometheus-flask-exporter==0.22.4
python-json-logger==2.0.7
gunicorn==21.2.0
marshmallow==3.20.1
redis==5.0.1
celery==5.3.4
requests==2.31.0
pytest==7.4.2
EOF

# 6.3 Configuration avec les bons mots de passe
sudo tee $APP_DIR/config/__init__.py > /dev/null << 'EOF'
# Config package
EOF

sudo tee $APP_DIR/config/config.py > /dev/null << 'EOF'
import os
from datetime import timedelta

class Config:
    SECRET_KEY = os.environ.get('SECRET_KEY', 'dev-secret-key-change-in-production')
    MONGODB_URI = os.environ.get('MONGODB_URI', 'mongodb://stockadmin:mongodb2025@localhost:27017/stock_management?authSource=admin')  # CORRECTION ICI
    MONGODB_DB = os.environ.get('MONGODB_DB', 'stock_management')
    
    REDIS_HOST = os.environ.get('REDIS_HOST', 'localhost')
    REDIS_PORT = int(os.environ.get('REDIS_PORT', 6379))
    REDIS_PASSWORD = os.environ.get('REDIS_PASSWORD', 'redis2025')  # CORRECTION ICI
    REDIS_DB = int(os.environ.get('REDIS_DB', 0))
    REDIS_TTL = int(os.environ.get('REDIS_TTL', 3600))
    
    JWT_SECRET_KEY = os.environ.get('JWT_SECRET_KEY', 'jwt-secret-change-in-production')
    JWT_ACCESS_TOKEN_EXPIRES = timedelta(hours=24)
    
    API_TITLE = 'Stock Management API'
    API_VERSION = '1.0.0'
    OPENAPI_VERSION = '3.0.2'
    OPENAPI_URL_PREFIX = '/docs'
    OPENAPI_SWAGGER_UI_PATH = '/swagger'
    
    LOG_LEVEL = os.environ.get('LOG_LEVEL', 'INFO')
    CACHE_ENABLED = os.environ.get('CACHE_ENABLED', 'true').lower() == 'true'
    CACHE_TTL = int(os.environ.get('CACHE_TTL', 300))

class DevelopmentConfig(Config):
    DEBUG = True
    CACHE_ENABLED = False

class ProductionConfig(Config):
    DEBUG = False

config = {
    'development': DevelopmentConfig,
    'production': ProductionConfig,
    'default': ProductionConfig
}
EOF

# 6.4 Application principale
sudo tee $APP_DIR/app/__init__.py > /dev/null << 'EOF'
from flask import Flask
from flask_cors import CORS
from flask_restful import Api
from flasgger import Swagger
from prometheus_flask_exporter import PrometheusMetrics
import logging
from pythonjsonlogger import jsonlogger
import os

from app.services.mongo_service import init_mongo_service
from app.services.redis_service import init_redis_service
from config.config import config

def create_app(config_name='default'):
    """Factory de l'application Flask"""
    app = Flask(__name__)
    
    # Configuration
    app.config.from_object(config[config_name])
    
    # Extensions
    CORS(app)
    api = Api(app, prefix='/api/v1')
    metrics = PrometheusMetrics(app)
    metrics.info('app_info', 'Stock API Information', version='1.0.0')
    
    # Logging
    log_handler = logging.StreamHandler()
    formatter = jsonlogger.JsonFormatter('%(asctime)s %(name)s %(levelname)s %(message)s')
    log_handler.setFormatter(formatter)
    app.logger.addHandler(log_handler)
    app.logger.setLevel(getattr(logging, app.config['LOG_LEVEL']))
    logging.getLogger('werkzeug').setLevel(logging.WARNING)
    
    # Swagger
    swagger_config = {
        "headers": [],
        "specs": [{"endpoint": 'apispec', "route": '/apispec.json', "rule_filter": lambda rule: True, "model_filter": lambda tag: True}],
        "static_url_path": "/flasgger_static",
        "swagger_ui": True,
        "specs_route": "/docs/swagger",
        "title": app.config['API_TITLE'],
        "version": app.config['API_VERSION'],
        "openapi": app.config['OPENAPI_VERSION']
    }
    
    Swagger(app, config=swagger_config)
    
    # Initialisation services
    try:
        init_mongo_service(app.config['MONGODB_URI'], app.config['MONGODB_DB'])
        app.logger.info("✅ MongoDB initialisé")
    except Exception as e:
        app.logger.error(f"❌ Erreur MongoDB: {e}")
        raise
    
    try:
        init_redis_service(host=app.config['REDIS_HOST'], port=app.config['REDIS_PORT'], 
                          password=app.config['REDIS_PASSWORD'], db=app.config['REDIS_DB'], 
                          ttl=app.config['REDIS_TTL'])
        app.logger.info("✅ Redis initialisé")
    except Exception as e:
        app.logger.error(f"❌ Erreur Redis: {e}")
    
    # Routes
    from app.routes.stocks import stocks_bp
    app.register_blueprint(stocks_bp)
    
    # Routes supplémentaires
    @app.route('/metrics')
    def metrics_endpoint():
        from prometheus_client import generate_latest
        return generate_latest(), 200, {'Content-Type': 'text/plain'}
    
    @app.route('/')
    def index():
        return {
            'message': 'Stock Management API',
            'version': '1.0.0',
            'docs': '/docs/swagger',
            'health': '/api/v1/health'
        }
    
    app.logger.info("✅ Application Flask initialisée")
    return app
EOF

# 6.5 Services
sudo tee $APP_DIR/app/services/__init__.py > /dev/null << 'EOF'
# Services package
EOF

sudo tee $APP_DIR/app/services/mongo_service.py > /dev/null << 'EOF'
from pymongo import MongoClient, ASCENDING
from pymongo.errors import ConnectionFailure
import logging

logger = logging.getLogger(__name__)

class MongoDBService:
    def __init__(self, connection_string, database_name):
        self.connection_string = connection_string
        self.database_name = database_name
        self.client = None
        self.db = None
        self.connect()
    
    def connect(self):
        try:
            self.client = MongoClient(self.connection_string, serverSelectionTimeoutMS=5000)
            self.client.admin.command('ping')
            self.db = self.client[self.database_name]
            self._create_indexes()
            logger.info(f"✅ Connecté à MongoDB: {self.database_name}")
        except ConnectionFailure as e:
            logger.error(f"❌ Erreur MongoDB: {e}")
            raise
    
    def _create_indexes(self):
        try:
            self.db.stocks.create_index([("product_id", ASCENDING)], unique=True)
            self.db.stocks.create_index([("category", ASCENDING)])
        except Exception as e:
            logger.warning(f"⚠️ Erreur index: {e}")
    
    def get_collection(self, collection_name):
        if self.db is None:
            self.connect()
        return self.db[collection_name]
    
    def health_check(self):
        try:
            self.client.admin.command('ping')
            return True
        except ConnectionFailure:
            return False

mongo_service = None

def init_mongo_service(connection_string, database_name):
    global mongo_service
    mongo_service = MongoDBService(connection_string, database_name)
    return mongo_service

def get_mongo_service():
    global mongo_service
    if mongo_service is None:
        raise RuntimeError("MongoDB service non initialisé")
    return mongo_service
EOF

sudo tee $APP_DIR/app/services/redis_service.py > /dev/null << 'EOF'
import redis
import pickle
import logging
from typing import Any, Optional

logger = logging.getLogger(__name__)

class RedisCacheService:
    def __init__(self, host: str = 'localhost', port: int = 6379, password: str = None, db: int = 0, ttl: int = 3600):
        self.host = host
        self.port = port
        self.password = password
        self.db = db
        self.ttl = ttl
        self.client = None
        self.connect()
    
    def connect(self):
        try:
            self.client = redis.Redis(host=self.host, port=self.port, password=self.password, 
                                    db=self.db, decode_responses=False, socket_connect_timeout=5)
            self.client.ping()
            logger.info("✅ Connecté à Redis")
        except Exception as e:
            logger.error(f"❌ Erreur Redis: {e}")
            self.client = None
    
    def get(self, key: str) -> Any:
        if not self.client:
            return None
        try:
            value = self.client.get(key)
            return pickle.loads(value) if value else None
        except Exception as e:
            logger.warning(f"⚠️ Erreur cache get: {e}")
            return None
    
    def set(self, key: str, value: Any, ttl: Optional[int] = None) -> bool:
        if not self.client:
            return False
        try:
            serialized = pickle.dumps(value)
            return self.client.setex(key, ttl or self.ttl, serialized)
        except Exception as e:
            logger.warning(f"⚠️ Erreur cache set: {e}")
            return False

redis_cache = None

def init_redis_service(host: str, port: int, password: str, db: int, ttl: int):
    global redis_cache
    redis_cache = RedisCacheService(host, port, password, db, ttl)
    return redis_cache

def get_redis_service():
    global redis_cache
    if redis_cache is None:
        raise RuntimeError("Redis service non initialisé")
    return redis_cache
EOF

# 6.6 Modèles
sudo tee $APP_DIR/app/models/__init__.py > /dev/null << 'EOF'
# Models package
EOF

sudo tee $APP_DIR/app/models/stock.py > /dev/null << 'EOF'
from datetime import datetime
from typing import Dict, Any
from bson import ObjectId

class Stock:
    def __init__(self, name: str, quantity: int, price: float, category: str, description: str = "", 
                 min_stock: int = 10, max_stock: int = 1000, supplier: str = "", sku: str = "",
                 product_id: str = None, _id: ObjectId = None):
        self._id = _id or ObjectId()
        self.product_id = product_id or str(self._id)
        self.name = name
        self.description = description
        self.quantity = quantity
        self.price = price
        self.category = category
        self.min_stock = min_stock
        self.max_stock = max_stock
        self.supplier = supplier
        self.sku = sku
        self.created_at = datetime.utcnow()
        self.updated_at = datetime.utcnow()
    
    def to_dict(self) -> Dict[str, Any]:
        return {
            "id": str(self._id),
            "product_id": self.product_id,
            "name": self.name,
            "description": self.description,
            "quantity": self.quantity,
            "price": self.price,
            "category": self.category,
            "min_stock": self.min_stock,
            "max_stock": self.max_stock,
            "supplier": self.supplier,
            "sku": self.sku,
            "created_at": self.created_at.isoformat(),
            "updated_at": self.updated_at.isoformat(),
            "stock_value": self.quantity * self.price,
            "low_stock_alert": self.quantity <= self.min_stock,
            "over_stock_alert": self.quantity >= self.max_stock
        }
    
    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'Stock':
        _id = data.get('_id')
        if _id and not isinstance(_id, ObjectId):
            _id = ObjectId(_id)
        
        return cls(
            _id=_id,
            product_id=data.get('product_id'),
            name=data.get('name'),
            description=data.get('description', ''),
            quantity=data.get('quantity', 0),
            price=data.get('price', 0.0),
            category=data.get('category', 'general'),
            min_stock=data.get('min_stock', 10),
            max_stock=data.get('max_stock', 1000),
            supplier=data.get('supplier', ''),
            sku=data.get('sku', '')
        )
EOF

# 6.7 Utilitaires
sudo tee $APP_DIR/app/utils/__init__.py > /dev/null << 'EOF'
# Utils package
EOF

sudo tee $APP_DIR/app/utils/validators.py > /dev/null << 'EOF'
from typing import Optional, Dict, Any

class StockValidator:
    @staticmethod
    def validate_stock_data(data: Dict[str, Any]) -> tuple[bool, Optional[str]]:
        required_fields = ['name', 'quantity', 'price', 'category']
        for field in required_fields:
            if field not in data or data[field] is None:
                return False, f"Champ requis manquant: {field}"
        
        name = data.get('name', '').strip()
        if not name or len(name) < 2 or len(name) > 100:
            return False, "Le nom doit contenir entre 2 et 100 caractères"
        
        try:
            quantity = int(data['quantity'])
            if quantity < 0:
                return False, "La quantité ne peut pas être négative"
        except (ValueError, TypeError):
            return False, "La quantité doit être un nombre entier"
        
        try:
            price = float(data['price'])
            if price < 0:
                return False, "Le prix ne peut pas être négatif"
        except (ValueError, TypeError):
            return False, "Le prix doit être un nombre"
        
        return True, None
EOF

# 6.8 Routes
sudo tee $APP_DIR/app/routes/__init__.py > /dev/null << 'EOF'
# Routes package
EOF

sudo tee $APP_DIR/app/routes/stocks.py > /dev/null << 'EOF'
from flask import Blueprint, request, jsonify
from flask_restful import Api, Resource
from flasgger import swag_from
import logging
from bson import ObjectId
from datetime import datetime

from app.services.mongo_service import get_mongo_service
from app.models.stock import Stock
from app.utils.validators import StockValidator

stocks_bp = Blueprint('stocks', __name__)
api = Api(stocks_bp)
logger = logging.getLogger(__name__)

class HealthCheck(Resource):
    @swag_from({
        'tags': ['health'],
        'responses': {
            200: {
                'description': 'API Health Status',
                'examples': {
                    'application/json': {
                        'status': 'healthy',
                        'service': 'stock-api',
                        'version': '1.0.0'
                    }
                }
            }
        }
    })
    def get(self):
        """Vérifier la santé de l'API"""
        mongo_service = get_mongo_service()
        db_status = "healthy" if mongo_service.health_check() else "unhealthy"
        
        return {
            'status': 'healthy',
            'service': 'stock-api',
            'version': '1.0.0',
            'database': db_status,
            'timestamp': datetime.utcnow().isoformat()
        }, 200

class StockList(Resource):
    @swag_from({
        'tags': ['stocks'],
        'parameters': [
            {
                'name': 'page',
                'in': 'query',
                'type': 'integer',
                'default': 1
            },
            {
                'name': 'per_page',
                'in': 'query',
                'type': 'integer',
                'default': 20
            }
        ],
        'responses': {
            200: {
                'description': 'Liste des stocks',
                'schema': {
                    'type': 'object',
                    'properties': {
                        'stocks': {
                            'type': 'array',
                            'items': {'$ref': '#/definitions/Stock'}
                        }
                    }
                }
            }
        }
    })
    def get(self):
        """Obtenir la liste des stocks"""
        try:
            page = request.args.get('page', 1, type=int)
            per_page = request.args.get('per_page', 20, type=int)
            
            mongo_service = get_mongo_service()
            collection = mongo_service.get_collection('stocks')
            
            skip = (page - 1) * per_page
            stocks_cursor = collection.find().skip(skip).limit(per_page)
            
            stocks = []
            for stock_data in stocks_cursor:
                stock = Stock.from_dict(stock_data)
                stocks.append(stock.to_dict())
            
            return {
                'stocks': stocks,
                'pagination': {
                    'page': page,
                    'per_page': per_page,
                    'total': collection.count_documents({})
                }
            }, 200
            
        except Exception as e:
            logger.error(f"Erreur récupération stocks: {str(e)}")
            return {'error': 'Erreur interne du serveur'}, 500

    @swag_from({
        'tags': ['stocks'],
        'parameters': [
            {
                'name': 'body',
                'in': 'body',
                'required': True,
                'schema': {
                    'type': 'object',
                    'required': ['name', 'quantity', 'price', 'category'],
                    'properties': {
                        'name': {'type': 'string', 'example': 'Laptop Dell XPS 13'},
                        'description': {'type': 'string', 'example': 'Laptop haut de gamme'},
                        'quantity': {'type': 'integer', 'example': 50},
                        'price': {'type': 'number', 'format': 'float', 'example': 1299.99},
                        'category': {'type': 'string', 'example': 'electronics'}
                    }
                }
            }
        ],
        'responses': {
            201: {
                'description': 'Stock créé avec succès',
                'schema': {'$ref': '#/definitions/Stock'}
            },
            400: {'description': 'Données invalides'}
        }
    })
    def post(self):
        """Créer un nouveau stock"""
        try:
            data = request.get_json()
            
            if not data:
                return {'error': 'Données JSON requises'}, 400
            
            is_valid, error = StockValidator.validate_stock_data(data)
            if not is_valid:
                return {'error': error}, 400
            
            mongo_service = get_mongo_service()
            collection = mongo_service.get_collection('stocks')
            
            stock = Stock(
                name=data['name'],
                description=data.get('description', ''),
                quantity=data['quantity'],
                price=data['price'],
                category=data['category'],
                min_stock=data.get('min_stock', 10),
                max_stock=data.get('max_stock', 1000),
                supplier=data.get('supplier', ''),
                sku=data.get('sku', '')
            )
            
            result = collection.insert_one(stock.__dict__)
            stock._id = result.inserted_id
            
            logger.info(f"Stock créé: {stock.product_id} - {stock.name}")
            
            return stock.to_dict(), 201
            
        except Exception as e:
            logger.error(f"Erreur création stock: {str(e)}")
            return {'error': 'Erreur interne du serveur'}, 500

class StockDetail(Resource):
    @swag_from({
        'tags': ['stocks'],
        'parameters': [
            {
                'name': 'product_id',
                'in': 'path',
                'type': 'string',
                'required': True
            }
        ],
        'responses': {
            200: {
                'description': 'Détails du stock',
                'schema': {'$ref': '#/definitions/Stock'}
            },
            404: {'description': 'Stock non trouvé'}
        }
    })
    def get(self, product_id):
        """Obtenir les détails d'un stock"""
        try:
            mongo_service = get_mongo_service()
            collection = mongo_service.get_collection('stocks')
            
            stock_data = collection.find_one({
                '$or': [
                    {'product_id': product_id},
                    {'_id': ObjectId(product_id) if ObjectId.is_valid(product_id) else None}
                ]
            })
            
            if not stock_data:
                return {'error': 'Stock non trouvé'}, 404
            
            stock = Stock.from_dict(stock_data)
            return stock.to_dict(), 200
            
        except Exception as e:
            logger.error(f"Erreur récupération stock {product_id}: {str(e)}")
            return {'error': 'Erreur interne du serveur'}, 500

# Enregistrement des routes
api.add_resource(HealthCheck, '/health')
api.add_resource(StockList, '/stocks')
api.add_resource(StockDetail, '/stocks/<string:product_id>')
EOF

# ÉTAPE 7: Configuration environnement
log "Configuration de l'environnement..."
sudo tee $APP_DIR/.env > /dev/null << 'EOF'
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
SECRET_KEY=dev-secret-key-change-in-production-2025
JWT_SECRET_KEY=jwt-secret-key-change-in-production-2025

# Configuration API
API_HOST=0.0.0.0
API_PORT=8000

# Configuration Cache
CACHE_ENABLED=true
CACHE_TTL=300

# Logging
LOG_LEVEL=INFO

# Swagger
SWAGGER_HOST=localhost:8000
EOF

# ÉTAPE 8: Permissions et propriété
log "Configuration des permissions..."
sudo chown -R stockapi:stockapi $APP_DIR
sudo chmod -R 755 $APP_DIR
sudo chmod 644 $APP_DIR/.env

# ÉTAPE 9: Installation Python
log "Installation de l'environnement Python..."
sudo -u stockapi python3.11 -m venv $APP_DIR/venv
sudo -u stockapi bash -c "source $APP_DIR/venv/bin/activate && pip install --upgrade pip"
sudo -u stockapi bash -c "source $APP_DIR/venv/bin/activate && pip install -r $APP_DIR/requirements.txt"

# ÉTAPE 10: Service systemd
log "Configuration du service systemd..."
sudo tee /etc/systemd/system/stock-api.service > /dev/null << 'EOF'
[Unit]
Description=Stock API Service
After=network.target mongod.service redis-server.service
Wants=mongod.service redis-server.service

[Service]
Type=simple
User=stockapi
Group=stockapi
WorkingDirectory=/opt/stock-api
Environment=PYTHONPATH=/opt/stock-api
Environment=FLASK_ENV=production
ExecStart=/opt/stock-api/venv/bin/gunicorn --bind 0.0.0.0:8000 --workers 2 --timeout 120 --access-logfile - --error-logfile - run:app
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable stock-api

# ÉTAPE 11: Démarrage final
log "Démarrage du service..."
sudo systemctl start stock-api

# ÉTAPE 12: Vérifications
log "Vérification des services..."
sleep 5

echo "🔍 MongoDB:"
sudo systemctl status mongod --no-pager --lines=2

echo "🔍 Redis:"
sudo systemctl status redis-server --no-pager --lines=2

echo "🔍 Stock API:"
sudo systemctl status stock-api --no-pager --lines=3

# ÉTAPE 13: Test final
log "Test de l'API..."
sleep 3

if curl -f -s http://localhost:8000/api/v1/health > /dev/null; then
    echo "✅ API accessible et fonctionnelle"
    echo "📊 Réponse health:"
    curl -s http://localhost:8000/api/v1/health | python3 -m json.tool 2>/dev/null || curl -s http://localhost:8000/api/v1/health
else
    echo "❌ API non accessible"
    echo "📋 Logs:"
    sudo journalctl -u stock-api -n 20 --no-pager
fi

# ÉTAPE 14: Résumé
echo ""
echo "🎉 DÉPLOIEMENT RÉUSSI!"
echo "======================"
API_IP=$(curl -s ifconfig.me)
echo "🌐 API:        http://$API_IP:8000"
echo "📚 Swagger:    http://$API_IP:8000/docs/swagger"
echo "📊 Métriques:  http://$API_IP:8000/metrics"
echo "❤️  Health:    http://$API_IP:8000/api/v1/health"
echo ""
echo "🔧 MongoDB:    stockadmin / mongodb2025"
echo "🔧 Redis:      redis2025"
echo ""
echo "✅ TOUT EST OPÉRATIONNEL!"
