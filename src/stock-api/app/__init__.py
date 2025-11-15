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
from config import config

def setup_logging(app):
    """Configuration du logging structuré"""
    log_handler = logging.StreamHandler()
    formatter = jsonlogger.JsonFormatter(
        '%(asctime)s %(name)s %(levelname)s %(message)s'
    )
    log_handler.setFormatter(formatter)
    
    app.logger.addHandler(log_handler)
    app.logger.setLevel(getattr(logging, app.config['LOG_LEVEL']))
    
    logging.getLogger('werkzeug').setLevel(logging.WARNING)

def setup_swagger(app):
    """Configuration de Swagger/OpenAPI"""
    swagger_config = {
        "headers": [],
        "specs": [
            {
                "endpoint": 'apispec',
                "route": '/apispec.json',
                "rule_filter": lambda rule: True,
                "model_filter": lambda tag: True,
            }
        ],
        "static_url_path": "/flasgger_static",
        "swagger_ui": True,
        "specs_route": "/docs/swagger",
        "title": app.config['API_TITLE'],
        "version": app.config['API_VERSION'],
        "openapi": app.config['OPENAPI_VERSION']
    }
    
    swagger_template = {
        "swagger": "2.0",
        "info": {
            "title": app.config['API_TITLE'],
            "description": "API complète de gestion de stocks avec MongoDB et Redis Cache",
            "version": app.config['API_VERSION'],
            "contact": {
                "name": "Support API",
                "url": "https://github.com/najeh-toumi-devops/kong-stack-project-azure"
            }
        },
        "host": os.environ.get('SWAGGER_HOST', 'localhost:8000'),
        "basePath": "/api/v1",
        "schemes": ["http", "https"],
        "definitions": {
            "Stock": {
                "type": "object",
                "properties": {
                    "id": {"type": "string"},
                    "product_id": {"type": "string"},
                    "name": {"type": "string"},
                    "description": {"type": "string"},
                    "quantity": {"type": "integer"},
                    "price": {"type": "number", "format": "float"},
                    "category": {"type": "string"},
                    "min_stock": {"type": "integer"},
                    "max_stock": {"type": "integer"},
                    "supplier": {"type": "string"},
                    "sku": {"type": "string"},
                    "created_at": {"type": "string", "format": "date-time"},
                    "updated_at": {"type": "string", "format": "date-time"},
                    "stock_value": {"type": "number", "format": "float"},
                    "low_stock_alert": {"type": "boolean"},
                    "over_stock_alert": {"type": "boolean"}
                }
            }
        }
    }
    
    Swagger(app, config=swagger_config, template=swagger_template)

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
    setup_logging(app)
    
    # Swagger
    setup_swagger(app)
    
    # Initialisation MongoDB
    try:
        init_mongo_service(app.config['MONGODB_URI'], app.config['MONGODB_DB'])
        app.logger.info("✅ MongoDB initialisé avec succès")
    except Exception as e:
        app.logger.error(f"❌ Erreur d'initialisation MongoDB: {e}")
        raise
    
    # Initialisation Redis
    try:
        init_redis_service(
            host=app.config['REDIS_HOST'],
            port=app.config['REDIS_PORT'],
            password=app.config['REDIS_PASSWORD'],
            db=app.config['REDIS_DB'],
            ttl=app.config['REDIS_TTL']
        )
        app.logger.info("✅ Redis initialisé avec succès")
    except Exception as e:
        app.logger.error(f"❌ Erreur d'initialisation Redis: {e}")
        # Ne pas bloquer le démarrage si Redis échoue
        if app.config['CACHE_ENABLED']:
            app.logger.warning("⚠️ Cache désactivé suite à l'erreur Redis")
    
    # Routes
    from app.routes.stocks import stocks_bp
    app.register_blueprint(stocks_bp)
    
    # Routes de métriques
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
            'health': '/api/v1/health',
            'cache_enabled': app.config['CACHE_ENABLED']
        }
    
    app.logger.info("✅ Application Flask initialisée avec succès")
    
    return app
