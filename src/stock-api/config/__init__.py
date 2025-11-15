import os
from datetime import timedelta

class Config:
    SECRET_KEY = os.environ.get('SECRET_KEY', 'dev-secret-key-change-in-production')
    MONGODB_URI = os.environ.get('MONGODB_URI', 'mongodb://stockadmin:mongodb2025@localhost:27017/stock_management?authSource=admin')
    MONGODB_DB = os.environ.get('MONGODB_DB', 'stock_management')
    
    REDIS_HOST = os.environ.get('REDIS_HOST', 'localhost')
    REDIS_PORT = int(os.environ.get('REDIS_PORT', 6379))
    REDIS_PASSWORD = os.environ.get('REDIS_PASSWORD', 'redis2025')
    REDIS_DB = int(os.environ.get('REDIS_DB', 0))
    REDIS_TTL = int(os.environ.get('REDIS_TTL', 3600))  # 1 heure
    
    JWT_SECRET_KEY = os.environ.get('JWT_SECRET_KEY', 'jwt-secret-change-in-production')
    JWT_ACCESS_TOKEN_EXPIRES = timedelta(hours=24)
    
    API_TITLE = 'Stock Management API'
    API_VERSION = '1.0.0'
    OPENAPI_VERSION = '3.0.2'
    OPENAPI_URL_PREFIX = '/docs'
    OPENAPI_SWAGGER_UI_PATH = '/swagger'
    
    LOG_LEVEL = os.environ.get('LOG_LEVEL', 'INFO')
    
    # Cache configuration
    CACHE_ENABLED = os.environ.get('CACHE_ENABLED', 'true').lower() == 'true'
    CACHE_TTL = int(os.environ.get('CACHE_TTL', 300))  # 5 minutes par défaut

class DevelopmentConfig(Config):
    DEBUG = True
    CACHE_ENABLED = False  # Désactiver le cache en développement

class ProductionConfig(Config):
    DEBUG = False

config = {
    'development': DevelopmentConfig,
    'production': ProductionConfig,
    'default': ProductionConfig
}
