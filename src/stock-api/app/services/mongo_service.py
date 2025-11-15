from pymongo import MongoClient, ASCENDING, DESCENDING
from pymongo.errors import ConnectionFailure, OperationFailure
import logging
from datetime import datetime

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
            self.client = MongoClient(
                self.connection_string,
                serverSelectionTimeoutMS=5000,
                connectTimeoutMS=5000,
                socketTimeoutMS=5000
            )
            
            self.client.admin.command('ping')
            self.db = self.client[self.database_name]
            self._create_indexes()
            
            logger.info(f"✅ Connecté à MongoDB: {self.database_name}")
            
        except ConnectionFailure as e:
            logger.error(f"❌ Erreur de connexion MongoDB: {e}")
            raise
    
    def _create_indexes(self):
        try:
            self.db.stocks.create_index([("product_id", ASCENDING)], unique=True)
            self.db.stocks.create_index([("category", ASCENDING)])
            self.db.stocks.create_index([("name", ASCENDING)])
            self.db.stocks.create_index([("quantity", ASCENDING)])
            self.db.stocks.create_index([("created_at", DESCENDING)])
            self.db.stock_history.create_index([("product_id", ASCENDING), ("timestamp", DESCENDING)])
            logger.info("✅ Index MongoDB créés")
        except OperationFailure as e:
            logger.warning(f"⚠️ Erreur création index: {e}")
    
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
    
    def close_connection(self):
        if self.client:
            self.client.close()
            logger.info("🔌 Connexion MongoDB fermée")

# Instance globale
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
