"""
Configuration management using Pydantic Settings
Supports:
1. Snowflake session token (from snow CLI) - highest priority
2. Configuration file with PAT or Keypair authentication
3. Direct credentials from environment variables
"""

from pydantic_settings import BaseSettings
from typing import List, Optional
import os
import toml
import json
from pathlib import Path
import logging

logger = logging.getLogger(__name__)

class Settings(BaseSettings):
    """Application settings"""
    
    # Environment
    ENVIRONMENT: str = "development"
    
    # Snow CLI connection (preferred method)
    SNOW_CONNECTION_NAME: Optional[str] = None
    
    # Configuration file path (for PAT or Keypair auth)
    CONFIG_FILE: Optional[str] = None
    
    # Direct Snowflake credentials (fallback)
    SNOWFLAKE_ACCOUNT: Optional[str] = None
    SNOWFLAKE_USER: Optional[str] = None
    SNOWFLAKE_PASSWORD: Optional[str] = None
    SNOWFLAKE_ROLE: str = "SYSADMIN"
    SNOWFLAKE_WAREHOUSE: str = "COMPUTE_WH"
    
    # PAT Authentication
    SNOWFLAKE_AUTHENTICATOR: Optional[str] = None  # "oauth" for PAT
    SNOWFLAKE_TOKEN: Optional[str] = None  # PAT token
    
    # Keypair Authentication
    SNOWFLAKE_PRIVATE_KEY_PATH: Optional[str] = None
    SNOWFLAKE_PRIVATE_KEY_PASSPHRASE: Optional[str] = None
    
    # Database Configuration
    DATABASE_NAME: str = "BORDEREAU_PROCESSING_PIPELINE"
    BRONZE_SCHEMA_NAME: str = "BRONZE"
    SILVER_SCHEMA_NAME: str = "SILVER"
    
    # API Configuration
    API_PREFIX: str = "/api"
    CORS_ORIGINS: List[str] = ["http://localhost:3000", "http://localhost:5173"]
    
    # File Upload
    MAX_UPLOAD_SIZE: int = 100 * 1024 * 1024  # 100 MB
    ALLOWED_EXTENSIONS: List[str] = [".csv", ".xlsx", ".xls"]
    
    # Processing
    BATCH_SIZE: int = 10000
    MAX_RETRIES: int = 3
    
    class Config:
        env_file = ".env"
        case_sensitive = True
    
    def get_snowflake_config(self) -> dict:
        """
        Get Snowflake connection configuration.
        Priority:
        1. Snowflake session token from filesystem (snow CLI)
        2. Configuration file (PAT or Keypair authentication)
        3. Direct credentials from environment variables
        """
        # 1. Try to use Snowflake session token first
        session_config = self._load_session_token()
        if session_config:
            logger.info("Using Snowflake session token from filesystem")
            return session_config
        
        # 2. Try to load from configuration file
        if self.CONFIG_FILE:
            config = self._load_config_file(self.CONFIG_FILE)
            if config:
                logger.info(f"Using configuration from file: {self.CONFIG_FILE}")
                return config
        
        # 3. Try to use snow CLI connection
        if self.SNOW_CONNECTION_NAME:
            try:
                config = self._load_snow_connection(self.SNOW_CONNECTION_NAME)
                if config:
                    logger.info(f"Using snow CLI connection: {self.SNOW_CONNECTION_NAME}")
                    return config
            except Exception as e:
                logger.warning(f"Could not load snow CLI connection: {e}")
        
        # 4. Fallback to direct credentials from environment
        return self._load_env_credentials()
    
    def _load_session_token(self) -> Optional[dict]:
        """
        Load Snowflake session token from filesystem.
        Snow CLI stores session tokens in ~/.snowflake/session/connections/
        """
        try:
            # Check for session token directory
            session_dir = Path.home() / '.snowflake' / 'session' / 'connections'
            
            if not session_dir.exists():
                return None
            
            # Look for default connection or specified connection
            connection_name = self.SNOW_CONNECTION_NAME or self._get_default_connection()
            
            if not connection_name:
                return None
            
            # Try to find session token file
            token_file = session_dir / f"{connection_name}.json"
            
            if not token_file.exists():
                return None
            
            # Load session token
            with open(token_file, 'r') as f:
                session_data = json.load(f)
            
            # Extract connection details
            if 'token' in session_data and 'account' in session_data:
                config = {
                    'account': session_data['account'],
                    'token': session_data['token'],
                    'authenticator': 'oauth',
                    'role': session_data.get('role', self.SNOWFLAKE_ROLE),
                    'warehouse': session_data.get('warehouse', self.SNOWFLAKE_WAREHOUSE),
                    'database': session_data.get('database', self.DATABASE_NAME),
                }
                
                # Add user if available
                if 'user' in session_data:
                    config['user'] = session_data['user']
                
                return config
            
            return None
            
        except Exception as e:
            logger.debug(f"Could not load session token: {e}")
            return None
    
    def _get_default_connection(self) -> Optional[str]:
        """Get the default connection name from snow CLI config"""
        try:
            config_path = Path.home() / '.snowflake' / 'connections.toml'
            
            if not config_path.exists():
                return None
            
            config = toml.load(config_path)
            
            # Find the connection marked as default
            for conn_name, conn_data in config.items():
                if isinstance(conn_data, dict) and conn_data.get('is_default'):
                    return conn_name
            
            return None
            
        except Exception as e:
            logger.debug(f"Could not determine default connection: {e}")
            return None
    
    def _load_config_file(self, config_file_path: str) -> Optional[dict]:
        """
        Load Snowflake configuration from a config file.
        Supports PAT and Keypair authentication.
        """
        try:
            config_path = Path(config_file_path)
            
            if not config_path.exists():
                logger.warning(f"Config file not found: {config_file_path}")
                return None
            
            # Load configuration based on file type
            if config_path.suffix == '.toml':
                config_data = toml.load(config_path)
            elif config_path.suffix == '.json':
                with open(config_path, 'r') as f:
                    config_data = json.load(f)
            else:
                # Try to load as shell config format
                config_data = self._load_shell_config(config_path)
            
            # Build connection config
            conn_config = {
                'account': config_data.get('SNOWFLAKE_ACCOUNT') or config_data.get('account'),
                'user': config_data.get('SNOWFLAKE_USER') or config_data.get('user'),
                'role': config_data.get('SNOWFLAKE_ROLE', self.SNOWFLAKE_ROLE),
                'warehouse': config_data.get('SNOWFLAKE_WAREHOUSE', self.SNOWFLAKE_WAREHOUSE),
                'database': config_data.get('DATABASE_NAME', self.DATABASE_NAME),
            }
            
            # Check for PAT authentication
            if config_data.get('SNOWFLAKE_AUTHENTICATOR') == 'oauth' or config_data.get('authenticator') == 'oauth':
                conn_config['authenticator'] = 'oauth'
                conn_config['token'] = config_data.get('SNOWFLAKE_TOKEN') or config_data.get('token')
                
                if not conn_config['token']:
                    logger.error("PAT authentication specified but no token provided")
                    return None
            
            # Check for Keypair authentication
            elif config_data.get('SNOWFLAKE_PRIVATE_KEY_PATH') or config_data.get('private_key_path'):
                private_key_path = config_data.get('SNOWFLAKE_PRIVATE_KEY_PATH') or config_data.get('private_key_path')
                passphrase = config_data.get('SNOWFLAKE_PRIVATE_KEY_PASSPHRASE') or config_data.get('private_key_passphrase')
                
                # Load private key
                private_key = self._load_private_key(private_key_path, passphrase)
                if private_key:
                    conn_config['private_key'] = private_key
                else:
                    logger.error("Failed to load private key")
                    return None
            
            # Standard password authentication
            elif config_data.get('SNOWFLAKE_PASSWORD') or config_data.get('password'):
                conn_config['password'] = config_data.get('SNOWFLAKE_PASSWORD') or config_data.get('password')
            else:
                logger.error("No valid authentication method found in config file")
                return None
            
            # Validate required fields
            if not conn_config.get('account') or not conn_config.get('user'):
                logger.error("Missing required fields: account and user")
                return None
            
            return conn_config
            
        except Exception as e:
            logger.error(f"Error loading config file: {e}")
            return None
    
    def _load_shell_config(self, config_path: Path) -> dict:
        """Load shell-style config file (KEY=VALUE format)"""
        config = {}
        
        with open(config_path, 'r') as f:
            for line in f:
                line = line.strip()
                
                # Skip comments and empty lines
                if not line or line.startswith('#'):
                    continue
                
                # Parse KEY=VALUE
                if '=' in line:
                    key, value = line.split('=', 1)
                    key = key.strip()
                    value = value.strip().strip('"').strip("'")
                    config[key] = value
        
        return config
    
    def _load_private_key(self, key_path: str, passphrase: Optional[str] = None) -> Optional[bytes]:
        """Load and decrypt private key for keypair authentication"""
        try:
            from cryptography.hazmat.backends import default_backend
            from cryptography.hazmat.primitives import serialization
            
            key_file = Path(key_path)
            
            if not key_file.exists():
                logger.error(f"Private key file not found: {key_path}")
                return None
            
            with open(key_file, 'rb') as f:
                private_key_data = f.read()
            
            # Load the private key
            passphrase_bytes = passphrase.encode() if passphrase else None
            
            private_key = serialization.load_pem_private_key(
                private_key_data,
                password=passphrase_bytes,
                backend=default_backend()
            )
            
            # Serialize to DER format (required by Snowflake connector)
            private_key_der = private_key.private_bytes(
                encoding=serialization.Encoding.DER,
                format=serialization.PrivateFormat.PKCS8,
                encryption_algorithm=serialization.NoEncryption()
            )
            
            return private_key_der
            
        except Exception as e:
            logger.error(f"Error loading private key: {e}")
            return None
    
    def _load_snow_connection(self, connection_name: str) -> Optional[dict]:
        """Load connection from snow CLI config file"""
        # Default snow CLI config location
        config_path = Path.home() / '.snowflake' / 'connections.toml'
        
        if not config_path.exists():
            return None
        
        try:
            config = toml.load(config_path)
            
            if connection_name not in config:
                return None
            
            conn = config[connection_name]
            
            return {
                'account': conn.get('account'),
                'user': conn.get('user'),
                'password': conn.get('password'),
                'role': conn.get('role', self.SNOWFLAKE_ROLE),
                'warehouse': conn.get('warehouse', self.SNOWFLAKE_WAREHOUSE),
                'database': conn.get('database', self.DATABASE_NAME),
            }
        except Exception as e:
            logger.error(f"Error loading snow connection: {e}")
            return None
    
    def _load_env_credentials(self) -> dict:
        """Load credentials from environment variables"""
        # Check for PAT authentication
        if self.SNOWFLAKE_AUTHENTICATOR == 'oauth' and self.SNOWFLAKE_TOKEN:
            return {
                'account': self.SNOWFLAKE_ACCOUNT,
                'user': self.SNOWFLAKE_USER,
                'authenticator': 'oauth',
                'token': self.SNOWFLAKE_TOKEN,
                'role': self.SNOWFLAKE_ROLE,
                'warehouse': self.SNOWFLAKE_WAREHOUSE,
                'database': self.DATABASE_NAME,
            }
        
        # Check for Keypair authentication
        if self.SNOWFLAKE_PRIVATE_KEY_PATH:
            private_key = self._load_private_key(
                self.SNOWFLAKE_PRIVATE_KEY_PATH,
                self.SNOWFLAKE_PRIVATE_KEY_PASSPHRASE
            )
            
            if private_key:
                return {
                    'account': self.SNOWFLAKE_ACCOUNT,
                    'user': self.SNOWFLAKE_USER,
                    'private_key': private_key,
                    'role': self.SNOWFLAKE_ROLE,
                    'warehouse': self.SNOWFLAKE_WAREHOUSE,
                    'database': self.DATABASE_NAME,
                }
        
        # Fallback to password authentication
        if not self.SNOWFLAKE_ACCOUNT or not self.SNOWFLAKE_USER or not self.SNOWFLAKE_PASSWORD:
            raise ValueError(
                "Snowflake credentials not configured. "
                "Please provide one of the following:\n"
                "1. Snowflake session token (via snow CLI)\n"
                "2. Configuration file (CONFIG_FILE) with PAT or Keypair auth\n"
                "3. Environment variables: SNOWFLAKE_ACCOUNT, SNOWFLAKE_USER, and "
                "SNOWFLAKE_PASSWORD (or SNOWFLAKE_TOKEN for PAT, or SNOWFLAKE_PRIVATE_KEY_PATH for keypair)"
            )
        
        return {
            'account': self.SNOWFLAKE_ACCOUNT,
            'user': self.SNOWFLAKE_USER,
            'password': self.SNOWFLAKE_PASSWORD,
            'role': self.SNOWFLAKE_ROLE,
            'warehouse': self.SNOWFLAKE_WAREHOUSE,
            'database': self.DATABASE_NAME,
        }

# Create settings instance
settings = Settings()
