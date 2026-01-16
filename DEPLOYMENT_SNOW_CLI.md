# Deployment Guide - Using Snowflake CLI

**Complete guide for deploying the Snowflake File Processing Pipeline using the Snowflake CLI (`snow`).**

## Overview

The deployment system now uses the **Snowflake CLI** for all Snowflake interactions, providing:
- ✅ Secure credential management via `~/.snowflake/connections.toml`
- ✅ No need to store passwords in config files
- ✅ Support for multiple Snowflake connections
- ✅ Consistent authentication across all tools
- ✅ Integration with Snowflake's native tooling

## Prerequisites

### 1. Install Snowflake CLI

```bash
# Install via pip
pip install snowflake-cli-labs

# Verify installation
snow --version
```

**Documentation**: https://docs.snowflake.com/en/developer-guide/snowflake-cli/installation/installation

### 2. Install jq (for JSON parsing)

```bash
# macOS
brew install jq

# Ubuntu/Debian
sudo apt-get install jq

# Windows (via Chocolatey)
choco install jq
```

## Quick Start

### Option 1: Automatic Setup (Recommended)

The deployment script will automatically check for and set up a Snowflake connection:

```bash
# Run deployment - it will guide you through connection setup if needed
./deploy.sh
```

The script will:
1. Check if `snow` CLI is installed
2. Check for existing connections
3. Prompt to create a new connection if none exists
4. Test the connection
5. Proceed with deployment

### Option 2: Manual Connection Setup

Set up your Snowflake connection before deployment:

```bash
# Add a new connection interactively
snow connection add

# Or add with parameters
snow connection add \
  --connection-name pipeline \
  --account abc12345.us-east-1 \
  --user your_username \
  --password your_password \
  --role SYSADMIN \
  --warehouse COMPUTE_WH \
  --database FILE_PROCESSING_PIPELINE \
  --default

# Test the connection
snow connection test --connection pipeline

# List all connections
snow connection list
```

## Deployment

### Deploy Complete Pipeline

```bash
# Use default connection
./deploy.sh

# Or specify a connection
./deploy.sh pipeline
```

### Deploy Individual Layers

```bash
# Bronze layer only
./deploy_bronze.sh pipeline

# Silver layer only
./deploy_silver.sh pipeline
```

## Connection Management

### View Connections

```bash
# List all connections
snow connection list

# Show connection details (JSON format)
snow connection list --format json

# Test a specific connection
snow connection test --connection pipeline
```

### Set Default Connection

```bash
# Set a connection as default
snow connection set-default --connection pipeline
```

### Update Connection

```bash
# Update connection details
snow connection add \
  --connection-name pipeline \
  --account new_account \
  --user new_user \
  --password new_password \
  --role SYSADMIN \
  --warehouse COMPUTE_WH \
  --database FILE_PROCESSING_PIPELINE \
  --default
```

### Remove Connection

```bash
# Remove a connection
snow connection remove --connection pipeline
```

## Configuration Files

### Snow CLI Configuration

Connections are stored in:
```
~/.snowflake/connections.toml
```

Example content:
```toml
[pipeline]
account = "abc12345.us-east-1"
user = "your_username"
password = "encrypted_password"
role = "SYSADMIN"
warehouse = "COMPUTE_WH"
database = "FILE_PROCESSING_PIPELINE"
```

**Note**: Passwords are encrypted by the Snow CLI.

### Backend Configuration

The FastAPI backend can use Snow CLI connections:

```bash
# backend/.env
ENVIRONMENT=development
SNOW_CONNECTION_NAME=pipeline
DATABASE_NAME=FILE_PROCESSING_PIPELINE
BRONZE_SCHEMA_NAME=BRONZE
SILVER_SCHEMA_NAME=SILVER
```

The backend will automatically read from `~/.snowflake/connections.toml`.

## Deployment Workflow

### 1. Initial Setup

```bash
# Clone repository
git clone <repository_url>
cd bordereau

# Make scripts executable
chmod +x deploy.sh deploy_bronze.sh deploy_silver.sh check_snow_connection.sh

# Run deployment (will guide through connection setup)
./deploy.sh
```

### 2. Connection Setup (Interactive)

If no connection exists, you'll be prompted:

```
Checking Snowflake CLI configuration...
✓ Snowflake CLI is installed

Setting up new Snowflake connection...

Please provide your Snowflake connection details:

Connection name (default: pipeline): pipeline
Account identifier (e.g., abc12345.us-east-1): abc12345.us-east-1
Username: your_username
Password: ********
Role (default: SYSADMIN): SYSADMIN
Warehouse (default: COMPUTE_WH): COMPUTE_WH
Database (default: FILE_PROCESSING_PIPELINE): FILE_PROCESSING_PIPELINE

Creating connection...
Testing connection...
✓ Connection established successfully
```

### 3. Deployment Execution

```
╔═══════════════════════════════════════════════════════════╗
║     SNOWFLAKE FILE PROCESSING PIPELINE DEPLOYMENT         ║
║              Using Snowflake CLI (snow)                   ║
╚═══════════════════════════════════════════════════════════╝

ℹ Using connection: pipeline
ℹ Account: abc12345.us-east-1
ℹ Database: FILE_PROCESSING_PIPELINE
ℹ Warehouse: COMPUTE_WH
ℹ Role: SYSADMIN

🥉 Deploying Bronze Layer...
Executing: bronze/1_Setup_Database_Roles.sql
Executing: bronze/2_Bronze_Schema_Tables.sql
...
✓ Bronze layer deployed successfully

🥈 Deploying Silver Layer...
Executing: silver/1_Silver_Schema_Setup.sql
...
✓ Silver layer deployed successfully

╔═══════════════════════════════════════════════════════════╗
║                  DEPLOYMENT SUMMARY                       ║
╠═══════════════════════════════════════════════════════════╣
║  Connection: pipeline
║  Database: FILE_PROCESSING_PIPELINE
║  Bronze Layer: ✓ Deployed
║  Silver Layer: ✓ Deployed
║  Duration: 4m 32s
╚═══════════════════════════════════════════════════════════╝
```

## Post-Deployment

### 1. Grant Task Privileges

```bash
# Requires ACCOUNTADMIN role
snow sql -f bronze/Fix_Task_Privileges.sql --connection pipeline
```

### 2. Upload Sample Data

```bash
# Upload sample files
snow stage put sample_data/claims_data/provider_a/*.csv \
  @BRONZE.SRC/provider_a/ \
  --connection pipeline \
  --auto-compress false
```

### 3. Start Backend (FastAPI)

```bash
cd backend

# Configure to use snow connection
cat > .env << EOF
ENVIRONMENT=development
SNOW_CONNECTION_NAME=pipeline
DATABASE_NAME=FILE_PROCESSING_PIPELINE
BRONZE_SCHEMA_NAME=BRONZE
SILVER_SCHEMA_NAME=SILVER
EOF

# Install dependencies
pip install -r requirements.txt

# Run backend
uvicorn app.main:app --reload
```

### 4. Start Frontend (React)

```bash
cd frontend

# Install dependencies
npm install

# Configure API URL
echo "VITE_API_URL=http://localhost:8000" > .env

# Run frontend
npm run dev
```

### 5. Access Applications

- **Frontend**: http://localhost:3000
- **Backend API**: http://localhost:8000
- **API Docs**: http://localhost:8000/api/docs

## Advanced Usage

### Multiple Environments

Set up different connections for different environments:

```bash
# Development
snow connection add --connection-name dev --account dev_account...

# Staging
snow connection add --connection-name staging --account staging_account...

# Production
snow connection add --connection-name prod --account prod_account...

# Deploy to specific environment
./deploy.sh dev
./deploy.sh staging
./deploy.sh prod
```

### Execute SQL Scripts

```bash
# Execute a single SQL file
snow sql -f bronze/1_Setup_Database_Roles.sql --connection pipeline

# Execute SQL from stdin
echo "SELECT CURRENT_VERSION();" | snow sql --stdin --connection pipeline

# Execute SQL query directly
snow sql -q "SELECT * FROM TPA_MASTER;" --connection pipeline
```

### Manage Snowflake Objects

```bash
# List databases
snow sql -q "SHOW DATABASES;" --connection pipeline

# List schemas
snow sql -q "SHOW SCHEMAS IN DATABASE FILE_PROCESSING_PIPELINE;" --connection pipeline

# List tables
snow sql -q "SHOW TABLES IN SCHEMA BRONZE;" --connection pipeline

# List tasks
snow sql -q "SHOW TASKS IN SCHEMA BRONZE;" --connection pipeline
```

## Troubleshooting

### Issue: Snow CLI not found

**Solution**: Install Snowflake CLI
```bash
pip install snowflake-cli-labs
```

### Issue: Connection test fails

**Solution**: Verify credentials
```bash
# Check connection details
snow connection list

# Test connection
snow connection test --connection pipeline

# Check account identifier format
# Should be: account_identifier.region (e.g., abc12345.us-east-1)
```

### Issue: jq not found

**Solution**: Install jq
```bash
# macOS
brew install jq

# Ubuntu/Debian
sudo apt-get install jq
```

### Issue: Permission denied on scripts

**Solution**: Make scripts executable
```bash
chmod +x deploy.sh deploy_bronze.sh deploy_silver.sh check_snow_connection.sh
```

### Issue: Backend can't read snow connection

**Solution**: Ensure backend has access to connections file
```bash
# Check file exists
ls -la ~/.snowflake/connections.toml

# Verify backend can read it
python -c "import toml; print(toml.load('~/.snowflake/connections.toml'))"

# Set connection name in backend/.env
echo "SNOW_CONNECTION_NAME=pipeline" >> backend/.env
```

## Security Best Practices

### 1. Connection Security

- ✅ Passwords are encrypted by Snow CLI
- ✅ Connections stored in user home directory
- ✅ File permissions restrict access
- ✅ No passwords in code or config files

### 2. Role-Based Access

```bash
# Use least privilege principle
# Development: Use read-only role
snow connection add --connection-name dev-readonly --role READONLY...

# Production: Use appropriate role
snow connection add --connection-name prod --role SYSADMIN...
```

### 3. Connection Rotation

```bash
# Regularly update passwords
snow connection add --connection-name pipeline --password new_password...

# Remove old connections
snow connection remove --connection old_connection
```

## Benefits of Snow CLI Approach

### vs. Direct Credentials in .env

| Aspect | Snow CLI | Direct .env |
|--------|----------|-------------|
| Security | ✅ Encrypted | ❌ Plain text |
| Management | ✅ Centralized | ❌ Per-project |
| Rotation | ✅ Easy | ❌ Manual |
| Multi-env | ✅ Built-in | ❌ Multiple files |
| Audit | ✅ Logged | ❌ No audit trail |

### vs. Snowflake Connector Direct

| Aspect | Snow CLI | Direct Connector |
|--------|----------|------------------|
| Setup | ✅ Interactive | ❌ Manual config |
| Testing | ✅ Built-in | ❌ Custom code |
| Credentials | ✅ Managed | ❌ In code |
| Updates | ✅ CLI commands | ❌ Code changes |

## Related Documentation

- [README_REACT.md](README_REACT.md) - React + FastAPI architecture
- [MIGRATION_GUIDE.md](MIGRATION_GUIDE.md) - Streamlit to React migration
- [Snowflake CLI Docs](https://docs.snowflake.com/en/developer-guide/snowflake-cli)

---

**Version**: 2.0  
**Last Updated**: January 15, 2026  
**Status**: ✅ Production Ready
