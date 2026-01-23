# Windows Deployment Guide

This guide explains how to deploy the Snowflake File Processing Pipeline from a Windows machine using batch files.

## Prerequisites

### Required Software

1. **Snowflake CLI (snow)**
   ```cmd
   pip install snowflake-cli-labs
   ```
   Or download from: https://docs.snowflake.com/en/developer-guide/snowflake-cli/index

2. **Docker Desktop** (for container deployment)
   - Download from: https://www.docker.com/products/docker-desktop/

3. **jq** (optional but recommended for JSON parsing)
   - Download from: https://stedolan.github.io/jq/download/
   - Place `jq.exe` in your PATH (e.g., `C:\Windows\System32\`)

### Snowflake Configuration

Configure your Snowflake connection:

```cmd
snow connection add
```

Or manually edit: `%USERPROFILE%\.snowflake\connections.toml`

Example configuration:
```toml
[connections.default]
account = "your-account"
user = "your-username"
password = "your-password"  # or use key-pair authentication
warehouse = "COMPUTE_WH"
database = "BORDEREAU_PROCESSING_PIPELINE"
schema = "PUBLIC"
role = "SYSADMIN"
```

## Configuration

### Default Configuration

The deployment uses `deployment\default.config` for default settings. To customize:

1. Copy `custom.config.example` to `custom.config`:
   ```cmd
   copy deployment\custom.config.example deployment\custom.config
   ```

2. Edit `custom.config` with your settings:
   ```properties
   DATABASE_NAME=BORDEREAU_PROCESSING_PIPELINE
   SNOWFLAKE_WAREHOUSE=COMPUTE_WH
   SNOWFLAKE_ROLE=SYSADMIN
   USE_DEFAULT_CONNECTION=true
   AUTO_APPROVE=false
   ```

## Deployment Options

### Option 1: Full Deployment (Recommended)

Deploy all layers (Bronze, Silver, Gold) in one command:

```cmd
cd deployment
deploy.bat
```

This will:
- Deploy Bronze layer (raw data ingestion)
- Deploy Silver layer (data transformation)
- Deploy Gold layer (analytics-ready data)
- Optionally load sample schemas
- Optionally deploy to Snowpark Container Services

### Option 2: Deploy with Specific Connection

```cmd
deploy.bat PRODUCTION
```

### Option 3: Deploy with Custom Config

```cmd
deploy.bat PRODUCTION path\to\custom.config
```

### Option 4: Verbose Deployment (for debugging)

```cmd
deploy.bat -v
```

### Option 5: Deploy Individual Layers

Deploy only specific layers:

```cmd
REM Bronze layer only
deploy_bronze.bat

REM Silver layer only
deploy_silver.bat

REM Gold layer only
deploy_gold.bat
```

## Container Deployment

To deploy the web application to Snowpark Container Services:

```cmd
cd deployment
deploy_container.bat
```

This will:
1. Create compute pool
2. Create image repository
3. Build Docker images (backend + frontend)
4. Push images to Snowflake
5. Deploy unified service

**Note:** Container deployment requires Docker Desktop to be running.

## Undeployment

To remove all deployed resources:

```cmd
cd deployment
undeploy.bat
```

Or use the deploy script with undeploy flag:

```cmd
deploy.bat -u
```

⚠️ **WARNING:** This will delete all data, schemas, and roles!

## Command Reference

### Main Deployment Script

```cmd
deploy.bat [OPTIONS] [CONNECTION_NAME] [CONFIG_FILE]

Options:
  -v, --verbose    Enable verbose logging
  -h, --help       Show help message
  -u, --undeploy   Remove all resources

Examples:
  deploy.bat                           # Use default connection
  deploy.bat -v                        # Verbose mode
  deploy.bat PRODUCTION                # Use specific connection
  deploy.bat PRODUCTION prod.config    # Use custom config
```

### Layer-Specific Scripts

```cmd
deploy_bronze.bat [CONNECTION_NAME]
deploy_silver.bat [CONNECTION_NAME]
deploy_gold.bat [CONNECTION_NAME]
```

### Container Deployment

```cmd
deploy_container.bat
```

### Utility Scripts

```cmd
check_snow_connection.bat    # Verify Snowflake CLI setup
undeploy.bat                 # Remove all resources
```

## Troubleshooting

### Issue: "snow is not recognized"

**Solution:** Install Snowflake CLI:
```cmd
pip install snowflake-cli-labs
```

### Issue: "jq is not recognized"

**Solution:** Either:
1. Install jq and add to PATH
2. Continue without jq (some features may be limited)

### Issue: "Docker is not running"

**Solution:** Start Docker Desktop before running container deployment.

### Issue: "Access Denied" or "Permission Denied"

**Solution:** 
1. Run Command Prompt as Administrator
2. Check Snowflake role permissions (need SYSADMIN, SECURITYADMIN)

### Issue: "Failed to create compute pool"

**Solution:** 
1. Verify you have ACCOUNTADMIN or appropriate privileges
2. Check if compute pool already exists
3. Verify account has Snowpark Container Services enabled

### Issue: Deployment hangs or times out

**Solution:**
1. Use verbose mode to see detailed output: `deploy.bat -v`
2. Check Snowflake query history for errors
3. Verify warehouse is running and accessible

## Differences from Linux/Mac Deployment

### Batch Files vs Shell Scripts

Windows uses `.bat` files instead of `.sh` files:
- `deploy.sh` → `deploy.bat`
- `deploy_bronze.sh` → `deploy_bronze.bat`
- etc.

### Path Separators

Windows uses backslashes (`\`) instead of forward slashes (`/`):
- Linux: `/path/to/file`
- Windows: `C:\path\to\file`

### Environment Variables

Windows uses `%VARIABLE%` instead of `$VARIABLE`:
- Linux: `$DATABASE_NAME`
- Windows: `%DATABASE_NAME%`

### Line Endings

Windows batch files use CRLF line endings. If you edit files in a Unix-style editor, ensure they're saved with Windows line endings.

## WSL Alternative

If you prefer using bash scripts on Windows, you can use Windows Subsystem for Linux (WSL):

1. Install WSL:
   ```cmd
   wsl --install
   ```

2. Use the original shell scripts:
   ```bash
   cd deployment
   ./deploy.sh
   ```

## Next Steps

After successful deployment:

1. **Upload Sample Data:**
   ```cmd
   snow stage put sample_data\claims_data\provider_a\*.csv @BRONZE.SRC/provider_a/ --connection default
   ```

2. **Start Local Development:**
   ```cmd
   docker-compose up -d
   ```

3. **Access Application:**
   - Local: http://localhost:3000
   - SPCS: Check service endpoint with `snow spcs service list-endpoints`

4. **Monitor Deployment:**
   ```sql
   -- Check Bronze layer
   SELECT * FROM BRONZE.file_processing_queue;
   
   -- Check Silver layer
   SELECT * FROM SILVER.target_schemas;
   
   -- Check Gold layer
   SELECT * FROM GOLD.v_gold_processing_summary;
   ```

## Support

For issues or questions:
1. Check the main README.md
2. Review DEPLOYMENT_SNOW_CLI.md
3. Check deployment logs in `logs\` directory
4. Review Snowflake query history for SQL errors

## Additional Resources

- [Snowflake CLI Documentation](https://docs.snowflake.com/en/developer-guide/snowflake-cli/index)
- [Snowpark Container Services](https://docs.snowflake.com/en/developer-guide/snowpark-container-services/overview)
- [Docker Desktop for Windows](https://docs.docker.com/desktop/install/windows-install/)
- [Windows Batch Scripting Guide](https://ss64.com/nt/)
