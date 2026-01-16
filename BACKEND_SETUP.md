# Backend Server Setup Guide

## Overview

The backend server has been configured with a flexible authentication system that supports multiple methods with the following priority:

1. **Snowflake Session Token** (from `snow` CLI) - Highest Priority
2. **Configuration File** (PAT or Keypair authentication)
3. **Snow CLI Connection** (from `~/.snowflake/connections.toml`)
4. **Environment Variables** (Password, PAT, or Keypair)

## Quick Start

### Option 1: Using Snowflake CLI Session Token (Recommended for Development)

If you're already logged in with the Snowflake CLI:

```bash
# Verify your snow CLI connection
snow connection test

# Start the backend server
cd backend
./start_server.sh
```

The server will automatically detect and use your session token from:
`~/.snowflake/session/connections/<connection-name>.json`

### Option 2: Using Configuration File (Recommended for Production)

1. Create a configuration file (choose format: `.toml`, `.json`, or `.env`):

**config.toml** (Recommended):
```toml
SNOWFLAKE_ACCOUNT = "your-account.region"
SNOWFLAKE_USER = "your-username"
SNOWFLAKE_AUTHENTICATOR = "oauth"
SNOWFLAKE_TOKEN = "your-pat-token"
SNOWFLAKE_ROLE = "SYSADMIN"
SNOWFLAKE_WAREHOUSE = "COMPUTE_WH"
DATABASE_NAME = "BORDEREAU_PROCESSING_PIPELINE"
```

2. Start the server with the config file:

```bash
cd backend
CONFIG_FILE=config.toml ./start_server.sh
```

### Option 3: Using Environment Variables

```bash
# Set environment variables
export SNOWFLAKE_ACCOUNT="your-account.region"
export SNOWFLAKE_USER="your-username"
export SNOWFLAKE_AUTHENTICATOR="oauth"
export SNOWFLAKE_TOKEN="your-pat-token"
export SNOWFLAKE_ROLE="SYSADMIN"
export SNOWFLAKE_WAREHOUSE="COMPUTE_WH"
export DATABASE_NAME="BORDEREAU_PROCESSING_PIPELINE"

# Start the server
cd backend
./start_server.sh
```

## Authentication Methods

### Personal Access Token (PAT) - Recommended

**Generate a PAT in Snowflake:**
1. Log in to Snowflake web UI
2. Click on your user profile
3. Navigate to "Personal Access Tokens"
4. Click "Generate New Token"
5. Copy the token (you won't be able to see it again)

**Configuration:**
```toml
SNOWFLAKE_AUTHENTICATOR = "oauth"
SNOWFLAKE_TOKEN = "your-pat-token"
```

### Keypair Authentication - Most Secure

**Generate keypair:**
```bash
# Generate private key
openssl genrsa 2048 | openssl pkcs8 -topk8 -inform PEM -out rsa_key.p8 -nocrypt

# Generate public key
openssl rsa -in rsa_key.p8 -pubout -out rsa_key.pub

# Extract public key value (remove headers and newlines)
grep -v "BEGIN PUBLIC" rsa_key.pub | grep -v "END PUBLIC" | tr -d '\n'
```

**Set public key in Snowflake:**
```sql
ALTER USER your_username SET RSA_PUBLIC_KEY='<public_key_value>';
```

**Configuration:**
```toml
SNOWFLAKE_PRIVATE_KEY_PATH = "/path/to/rsa_key.p8"
SNOWFLAKE_PRIVATE_KEY_PASSPHRASE = "your-passphrase"  # Optional if encrypted
```

### Password Authentication - Not Recommended for Production

```toml
SNOWFLAKE_PASSWORD = "your-password"
```

## Example Configuration Files

Example configuration files are provided in the `backend` directory:

- `config.example.toml` - TOML format (recommended)
- `config.example.json` - JSON format
- `config.example.env` - Shell/ENV format

Copy one of these files and customize it for your environment:

```bash
cd backend
cp config.example.toml config.toml
# Edit config.toml with your credentials
nano config.toml
```

## Server Management

### Start the Server

```bash
cd backend
./start_server.sh
```

The server will start on `http://localhost:8000` by default.

### Custom Port

```bash
PORT=8080 ./start_server.sh
```

### Production Mode (No Auto-Reload)

```bash
RELOAD=false ./start_server.sh
```

### Check Server Status

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

## API Documentation

Once the server is running, access the interactive API documentation:

- **Swagger UI:** http://localhost:8000/api/docs
- **ReDoc:** http://localhost:8000/api/redoc

## Troubleshooting

### "No authentication method configured"

This means the server couldn't find any valid authentication. Try:

1. Check if you're logged in with snow CLI: `snow connection test`
2. Verify your config file path: `echo $CONFIG_FILE`
3. Check environment variables: `env | grep SNOWFLAKE`

### "Failed to connect to Snowflake"

- Verify your account identifier format: `account.region` (e.g., `xy12345.us-east-1`)
- Check network connectivity
- Ensure your user has appropriate permissions
- Verify the role and warehouse exist

### "Token expired"

- For PAT: Regenerate the token in Snowflake UI
- For session token: Run `snow connection test` to refresh

## Security Best Practices

1. **Never commit credentials** to version control
2. Add `config.toml`, `config.json`, `.env` to `.gitignore`
3. **Use PAT or Keypair** authentication in production
4. **Rotate tokens regularly**
5. **Use encrypted private keys** for keypair authentication
6. **Set appropriate file permissions**: `chmod 600 config.toml`
7. **Use HTTPS** in production
8. **Implement rate limiting** for production deployments

## Full Documentation

For complete documentation, see:
- `backend/README.md` - Comprehensive backend documentation
- API Documentation - http://localhost:8000/api/docs (when server is running)
