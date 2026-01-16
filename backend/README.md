# Snowflake Pipeline Backend API

FastAPI backend for the Snowflake File Processing Pipeline with Bronze and Silver layers.

## Authentication Methods

The backend supports multiple authentication methods with the following priority:

1. **Snowflake Session Token** (Highest Priority)
2. **Configuration File** (PAT or Keypair)
3. **Snow CLI Connection**
4. **Environment Variables**

### 1. Snowflake Session Token (Recommended for Development)

If you're using the Snowflake CLI (`snow`), the backend will automatically detect and use your active session token.

```bash
# Login with snow CLI
snow connection test

# The backend will automatically use the session token from:
# ~/.snowflake/session/connections/<connection-name>.json
```

**Advantages:**
- No configuration needed
- Automatically refreshed by snow CLI
- Secure token-based authentication

### 2. Configuration File (Recommended for Production)

Create a configuration file with your Snowflake credentials. Supports multiple formats:

#### Using Personal Access Token (PAT)

**config.toml:**
```toml
SNOWFLAKE_ACCOUNT = "your-account.region"
SNOWFLAKE_USER = "your-username"
SNOWFLAKE_AUTHENTICATOR = "oauth"
SNOWFLAKE_TOKEN = "your-pat-token"
SNOWFLAKE_ROLE = "SYSADMIN"
SNOWFLAKE_WAREHOUSE = "COMPUTE_WH"
DATABASE_NAME = "BORDEREAU_PROCESSING_PIPELINE"
```

**config.json:**
```json
{
  "SNOWFLAKE_ACCOUNT": "your-account.region",
  "SNOWFLAKE_USER": "your-username",
  "SNOWFLAKE_AUTHENTICATOR": "oauth",
  "SNOWFLAKE_TOKEN": "your-pat-token",
  "SNOWFLAKE_ROLE": "SYSADMIN",
  "SNOWFLAKE_WAREHOUSE": "COMPUTE_WH",
  "DATABASE_NAME": "BORDEREAU_PROCESSING_PIPELINE"
}
```

**How to generate a PAT:**
1. Log in to Snowflake web UI
2. Go to your user profile
3. Navigate to "Personal Access Tokens"
4. Click "Generate New Token"
5. Copy the token (you won't be able to see it again)

#### Using Keypair Authentication (Most Secure)

**Generate keypair:**
```bash
# Generate private key
openssl genrsa 2048 | openssl pkcs8 -topk8 -inform PEM -out rsa_key.p8 -nocrypt

# Generate public key
openssl rsa -in rsa_key.p8 -pubout -out rsa_key.pub

# Set the public key in Snowflake
# ALTER USER your_username SET RSA_PUBLIC_KEY='<public_key_value>';
```

**config.toml:**
```toml
SNOWFLAKE_ACCOUNT = "your-account.region"
SNOWFLAKE_USER = "your-username"
SNOWFLAKE_PRIVATE_KEY_PATH = "/path/to/rsa_key.p8"
SNOWFLAKE_PRIVATE_KEY_PASSPHRASE = "your-passphrase"  # Optional
SNOWFLAKE_ROLE = "SYSADMIN"
SNOWFLAKE_WAREHOUSE = "COMPUTE_WH"
DATABASE_NAME = "BORDEREAU_PROCESSING_PIPELINE"
```

**Start the server with config file:**
```bash
CONFIG_FILE=config.toml python -m uvicorn app.main:app --reload
```

### 3. Snow CLI Connection

Set the connection name in environment variables:

```bash
export SNOW_CONNECTION_NAME="DEPLOYMENT"
python -m uvicorn app.main:app --reload
```

### 4. Environment Variables

Create a `.env` file or export variables:

```bash
# Password authentication
export SNOWFLAKE_ACCOUNT="your-account.region"
export SNOWFLAKE_USER="your-username"
export SNOWFLAKE_PASSWORD="your-password"
export SNOWFLAKE_ROLE="SYSADMIN"
export SNOWFLAKE_WAREHOUSE="COMPUTE_WH"
export DATABASE_NAME="BORDEREAU_PROCESSING_PIPELINE"

# Or PAT authentication
export SNOWFLAKE_AUTHENTICATOR="oauth"
export SNOWFLAKE_TOKEN="your-pat-token"

# Or Keypair authentication
export SNOWFLAKE_PRIVATE_KEY_PATH="/path/to/rsa_key.p8"
export SNOWFLAKE_PRIVATE_KEY_PASSPHRASE="your-passphrase"
```

## Installation

```bash
# Create virtual environment
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt
```

## Running the Server

### Development Mode

```bash
# Using session token (if logged in with snow CLI)
python -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

# Using configuration file
CONFIG_FILE=config.toml python -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

# Using environment variables
python -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

### Production Mode

```bash
# Using gunicorn with uvicorn workers
gunicorn app.main:app \
  --workers 4 \
  --worker-class uvicorn.workers.UvicornWorker \
  --bind 0.0.0.0:8000 \
  --access-logfile - \
  --error-logfile -
```

## API Documentation

Once the server is running, access the interactive API documentation:

- **Swagger UI:** http://localhost:8000/api/docs
- **ReDoc:** http://localhost:8000/api/redoc
- **OpenAPI JSON:** http://localhost:8000/api/openapi.json

## Health Check

```bash
curl http://localhost:8000/api/health
```

Expected response:
```json
{
  "status": "healthy",
  "snowflake": "connected",
  "version": "8.x.x"
}
```

## API Endpoints

### TPA Management
- `GET /api/tpas` - List all TPAs
- `POST /api/tpas` - Create new TPA
- `GET /api/tpas/{tpa_code}` - Get TPA details
- `PUT /api/tpas/{tpa_code}` - Update TPA
- `DELETE /api/tpas/{tpa_code}` - Delete TPA

### Bronze Layer
- `POST /api/bronze/upload` - Upload file to Bronze layer
- `GET /api/bronze/queue` - Get processing queue
- `GET /api/bronze/data` - Get raw data
- `GET /api/bronze/stages` - List stage files

### Silver Layer
- `GET /api/silver/schemas` - Get target schemas
- `GET /api/silver/mappings` - Get field mappings
- `POST /api/silver/transform` - Trigger transformation

## Configuration Options

| Variable | Description | Default |
|----------|-------------|---------|
| `CONFIG_FILE` | Path to configuration file | None |
| `SNOW_CONNECTION_NAME` | Snow CLI connection name | None |
| `SNOWFLAKE_ACCOUNT` | Snowflake account identifier | Required |
| `SNOWFLAKE_USER` | Snowflake username | Required |
| `SNOWFLAKE_PASSWORD` | Password (if using password auth) | None |
| `SNOWFLAKE_AUTHENTICATOR` | Set to "oauth" for PAT | None |
| `SNOWFLAKE_TOKEN` | PAT token | None |
| `SNOWFLAKE_PRIVATE_KEY_PATH` | Path to private key file | None |
| `SNOWFLAKE_PRIVATE_KEY_PASSPHRASE` | Private key passphrase | None |
| `SNOWFLAKE_ROLE` | Snowflake role | SYSADMIN |
| `SNOWFLAKE_WAREHOUSE` | Snowflake warehouse | COMPUTE_WH |
| `DATABASE_NAME` | Database name | BORDEREAU_PROCESSING_PIPELINE |
| `BRONZE_SCHEMA_NAME` | Bronze schema name | BRONZE |
| `SILVER_SCHEMA_NAME` | Silver schema name | SILVER |
| `ENVIRONMENT` | Environment (dev/staging/prod) | development |
| `MAX_UPLOAD_SIZE` | Max file upload size in bytes | 104857600 (100MB) |
| `BATCH_SIZE` | Processing batch size | 10000 |
| `MAX_RETRIES` | Max retry attempts | 3 |

## Security Best Practices

1. **Never commit credentials** to version control
2. **Use PAT or Keypair** authentication in production
3. **Rotate tokens regularly** (PATs can be set to expire)
4. **Use encrypted private keys** for keypair authentication
5. **Set appropriate CORS origins** for your environment
6. **Use HTTPS** in production
7. **Implement rate limiting** for production deployments
8. **Monitor API access logs** regularly

## Troubleshooting

### Connection Issues

```bash
# Test Snowflake connection
python -c "from app.config import settings; print(settings.get_snowflake_config())"

# Check if session token exists
ls -la ~/.snowflake/session/connections/

# Verify snow CLI connection
snow connection test
```

### Common Errors

**Error: "Snowflake credentials not configured"**
- Ensure you have one of the authentication methods configured
- Check that environment variables are set correctly
- Verify config file path is correct

**Error: "Failed to connect to Snowflake"**
- Verify account identifier is correct (should be: account.region)
- Check network connectivity
- Ensure user has appropriate permissions
- Verify role and warehouse exist

**Error: "Private key file not found"**
- Check the path to your private key file
- Ensure the file has proper permissions (chmod 600)

**Error: "Token expired"**
- Regenerate PAT in Snowflake UI
- For session tokens, run: `snow connection test` to refresh

## Development

### Running Tests

```bash
pytest tests/
```

### Code Style

```bash
# Format code
black app/

# Lint code
flake8 app/

# Type checking
mypy app/
```

## Docker

Build and run with Docker:

```bash
# Build image
docker build -t bordereau-backend -f docker/Dockerfile.backend .

# Run container with config file
docker run -p 8000:8000 \
  -v $(pwd)/config.toml:/app/config.toml \
  -e CONFIG_FILE=/app/config.toml \
  bordereau-backend

# Run with environment variables
docker run -p 8000:8000 \
  -e SNOWFLAKE_ACCOUNT="your-account" \
  -e SNOWFLAKE_USER="your-user" \
  -e SNOWFLAKE_TOKEN="your-token" \
  -e SNOWFLAKE_AUTHENTICATOR="oauth" \
  bordereau-backend
```

## License

See LICENSE file in the root directory.
