# Deployment Configuration Summary

## Overview
The deployment script now provides comprehensive configuration display and flexible approval options for deploying the Snowflake File Processing Pipeline.

## Configuration Options

### Connection Management
- **SNOWFLAKE_CONNECTION**: Specify a connection name, or leave empty to prompt for selection
- **USE_DEFAULT_CONNECTION**: Set to `true` to automatically use the default Snowflake CLI connection

### Approval Options
- **AUTO_APPROVE**: Set to `true` to skip the deployment confirmation prompt (useful for CI/CD)

## Deployment Configuration Display

Before deployment, the script displays:

### Basic Configuration
- Connection name
- Database name
- Warehouse
- Bronze schema name
- Silver schema name

### Objects to be Created

#### Database
- Target database (e.g., `BORDEREAU_PROCESSING_PIPELINE`)

#### Schemas
- Bronze schema (e.g., `BORDEREAU_PROCESSING_PIPELINE.BRONZE`)
- Silver schema (e.g., `BORDEREAU_PROCESSING_PIPELINE.SILVER`)

#### Roles
- `{DATABASE}_ADMIN` - Full administrative access
- `{DATABASE}_READWRITE` - Read/write access + execute procedures
- `{DATABASE}_READONLY` - Read-only access

#### Bronze Layer Objects
- **Stages**: @SRC, @COMPLETED, @ERROR, @ARCHIVE
- **Tables**: TPA_MASTER, RAW_DATA_TABLE, file_processing_queue
- **Procedures**: process_csv_file, process_excel_file, discover_files, etc.
- **Tasks**: File discovery, processing, movement, archival

#### Silver Layer Objects
- **Tables**: target_schemas, field_mappings, transformation_rules
- **Procedures**: create_silver_table, transform_bronze_to_silver, etc.
- **Tasks**: Bronze to Silver transformation

## Usage Examples

### Interactive Deployment (Default)
```bash
./deploy.sh
```
- Prompts for connection selection (if not configured)
- Displays configuration
- Asks for confirmation before proceeding

### Automated Deployment (CI/CD)
```bash
# In default.config or custom.config
USE_DEFAULT_CONNECTION="true"
AUTO_APPROVE="true"

./deploy.sh
```
- Uses default connection automatically
- Displays configuration
- Proceeds without confirmation

### Specific Connection with Confirmation
```bash
./deploy.sh PRODUCTION
```
- Uses specified connection
- Displays configuration
- Asks for confirmation

### Verbose Deployment
```bash
./deploy.sh -v
```
- Shows all SQL statements and output
- Useful for debugging

## Configuration File Priority

Configuration is loaded in this order (later files override earlier):
1. `default.config` (always loaded if exists)
2. `custom.config` (loaded if exists)
3. Command-line specified config file (if provided)

## Example Configuration

```bash
# custom.config
SNOWFLAKE_CONNECTION="PRODUCTION"
USE_DEFAULT_CONNECTION="false"
AUTO_APPROVE="false"
DATABASE_NAME="MY_PIPELINE"
SNOWFLAKE_WAREHOUSE="COMPUTE_WH"
BRONZE_SCHEMA_NAME="BRONZE"
SILVER_SCHEMA_NAME="SILVER"
```
