"""
Simple in-memory cache for API responses
"""

from functools import wraps
from datetime import datetime, timedelta
from typing import Any, Dict, Optional, Callable
import logging

logger = logging.getLogger(__name__)

class SimpleCache:
    """Simple in-memory cache with TTL"""
    
    def __init__(self):
        self._cache: Dict[str, Dict[str, Any]] = {}
    
    def get(self, key: str) -> Optional[Any]:
        """Get value from cache if not expired"""
        if key in self._cache:
            entry = self._cache[key]
            if datetime.now() < entry['expires_at']:
                logger.debug(f"Cache HIT: {key}")
                return entry['value']
            else:
                logger.debug(f"Cache EXPIRED: {key}")
                del self._cache[key]
        logger.debug(f"Cache MISS: {key}")
        return None
    
    def set(self, key: str, value: Any, ttl_seconds: int = 60):
        """Set value in cache with TTL"""
        self._cache[key] = {
            'value': value,
            'expires_at': datetime.now() + timedelta(seconds=ttl_seconds)
        }
        logger.debug(f"Cache SET: {key} (TTL: {ttl_seconds}s)")
    
    def clear(self, pattern: Optional[str] = None):
        """Clear cache entries matching pattern or all if pattern is None"""
        if pattern is None:
            self._cache.clear()
            logger.info("Cache cleared (all)")
        else:
            keys_to_delete = [k for k in self._cache.keys() if pattern in k]
            for key in keys_to_delete:
                del self._cache[key]
            logger.info(f"Cache cleared ({len(keys_to_delete)} entries matching '{pattern}')")

# Global cache instance
cache = SimpleCache()

def cached(ttl_seconds: int = 60, key_prefix: str = ""):
    """Decorator to cache function results"""
    def decorator(func: Callable) -> Callable:
        @wraps(func)
        def wrapper(*args, **kwargs):
            # Generate cache key from function name and arguments
            cache_key = f"{key_prefix}:{func.__name__}:{str(args)}:{str(kwargs)}"
            
            # Try to get from cache
            cached_value = cache.get(cache_key)
            if cached_value is not None:
                return cached_value
            
            # Execute function and cache result
            result = func(*args, **kwargs)
            cache.set(cache_key, result, ttl_seconds)
            return result
        
        return wrapper
    return decorator
