import redis
import json
import logging
from typing import Any, Optional, Union
from datetime import timedelta
import pickle

logger = logging.getLogger(__name__)

class RedisCacheService:
    def __init__(self, host: str = 'localhost', port: int = 6379, 
                 password: str = None, db: int = 0, default_ttl: int = 3600):
        self.host = host
        self.port = port
        self.password = password
        self.db = db
        self.default_ttl = default_ttl
        self.client = None
        self.connect()
    
    def connect(self):
        try:
            self.client = redis.Redis(
                host=self.host,
                port=self.port,
                password=self.password,
                db=self.db,
                socket_connect_timeout=5,
                socket_timeout=5,
                retry_on_timeout=True,
                decode_responses=False
            )
            
            self.client.ping()
            logger.info("✅ Connecté à Redis avec succès")
            
        except redis.ConnectionError as e:
            logger.error(f"❌ Erreur de connexion Redis: {e}")
            self.client = None
    
    def is_connected(self) -> bool:
        try:
            return self.client is not None and self.client.ping()
        except:
            return False
    
    def get(self, key: str) -> Any:
        if not self.is_connected():
            return None
        
        try:
            value = self.client.get(key)
            if value:
                return pickle.loads(value)
            return None
        except Exception as e:
            logger.warning(f"⚠️ Erreur récupération cache {key}: {e}")
            return None
    
    def set(self, key: str, value: Any, ttl: Optional[int] = None) -> bool:
        if not self.is_connected():
            return False
        
        try:
            serialized_value = pickle.dumps(value)
            actual_ttl = ttl if ttl is not None else self.default_ttl
            result = self.client.setex(key, actual_ttl, serialized_value)
            return result
        except Exception as e:
            logger.warning(f"⚠️ Erreur stockage cache {key}: {e}")
            return False
    
    def delete(self, key: str) -> bool:
        if not self.is_connected():
            return False
        
        try:
            result = self.client.delete(key)
            return result > 0
        except Exception as e:
            logger.warning(f"⚠️ Erreur suppression cache {key}: {e}")
            return False
    
    def exists(self, key: str) -> bool:
        if not self.is_connected():
            return False
        
        try:
            return self.client.exists(key) > 0
        except Exception as e:
            logger.warning(f"⚠️ Erreur vérification cache {key}: {e}")
            return False
    
    def clear_pattern(self, pattern: str) -> int:
        if not self.is_connected():
            return 0
        
        try:
            keys = self.client.keys(pattern)
            if keys:
                return self.client.delete(*keys)
            return 0
        except Exception as e:
            logger.warning(f"⚠️ Erreur nettoyage cache {pattern}: {e}")
            return 0
    
    def get_stats(self) -> dict:
        if not self.is_connected():
            return {"connected": False}
        
        try:
            info = self.client.info()
            hits = info.get('keyspace_hits', 0)
            misses = info.get('keyspace_misses', 0)
            total = hits + misses
            hit_rate = (hits / total * 100) if total > 0 else 0
            
            return {
                "connected": True,
                "used_memory": info.get('used_memory', 0),
                "used_memory_human": info.get('used_memory_human', '0B'),
                "keyspace_hits": hits,
                "keyspace_misses": misses,
                "hit_rate": round(hit_rate, 2),
                "total_commands_processed": info.get('total_commands_processed', 0),
                "connected_clients": info.get('connected_clients', 0)
            }
        except Exception as e:
            logger.warning(f"⚠️ Erreur récupération stats Redis: {e}")
            return {"connected": False}
    
    def _calculate_hit_rate(self, hits: int, misses: int) -> float:
        total = hits + misses
        return (hits / total * 100) if total > 0 else 0.0

# Instance globale
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
