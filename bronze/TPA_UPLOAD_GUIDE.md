# TPA File Upload Guide

**Complete guide for uploading files with TPA organization in the Bronze layer.**

## Overview

The Bronze layer requires files to be organized by TPA (Third Party Administrator) for proper processing and data isolation. This guide explains how to upload files correctly.

## TPA File Organization

### Required Structure

Files must be uploaded to TPA-specific folders in the `@SRC` stage:

```
@SRC/
├── provider_a/
│   ├── claims-20240301.csv
│   └── members-20240301.csv
├── provider_b/
│   ├── claims-20240115.csv
│   └── eligibility-20240115.xlsx
└── provider_c/
    └── claims-20240215.xlsx
```

### TPA Naming Convention

- **TPA codes**: Lowercase with underscores (e.g., `provider_a`, `blue_cross_shield`)
- **Folder names**: Must match TPA code exactly
- **File names**: Can be any valid filename (no restrictions)

## Upload Methods

### Method 1: React UI (Recommended)

**Steps:**

1. Open the React frontend at `http://localhost:3000`
2. In the sidebar, navigate to **📤 Upload Files**
3. Select TPA from dropdown (e.g., `provider_a`)
4. Drag and drop files or click to browse
5. Click **Upload** button
6. Files are automatically uploaded to `@SRC/{tpa}/`

**Advantages:**
- User-friendly interface
- Automatic TPA folder creation
- Progress tracking
- Immediate feedback

**Supported Formats:**
- CSV (`.csv`)
- Excel (`.xlsx`, `.xls`)

### Method 2: SnowSQL

**Upload single file:**

```sql
-- Upload to specific TPA folder
PUT file:///path/to/claims.csv @SRC/provider_a/ AUTO_COMPRESS=FALSE;

-- Upload multiple files
PUT file:///path/to/data/*.csv @SRC/provider_b/ AUTO_COMPRESS=FALSE;
```

**Upload from directory:**

```bash
# Upload all CSV files from directory
snowsql -q "PUT file:///path/to/claims/*.csv @SRC/provider_a/ AUTO_COMPRESS=FALSE;"

# Upload all Excel files
snowsql -q "PUT file:///path/to/data/*.xlsx @SRC/provider_b/ AUTO_COMPRESS=FALSE;"
```

**Advantages:**
- Scriptable for automation
- Bulk upload support
- Command-line integration

### Method 3: Snowflake Web UI

**Steps:**

1. Log in to Snowflake web interface
2. Navigate to **Data** → **Databases**
3. Select your database → **BRONZE** schema
4. Click **Stages** → **SRC**
5. Click **+ Files** button
6. Navigate to TPA folder (or create new folder)
7. Upload files

**Advantages:**
- No CLI required
- Visual file browser
- Easy folder management

### Method 4: Snowflake CLI (snow)

```bash
# Upload file using Snowflake CLI
snow stage put /path/to/claims.csv @SRC/provider_a/ --overwrite

# Upload directory
snow stage put /path/to/data/* @SRC/provider_b/ --overwrite
```

## Before Uploading

### 1. Register TPA

Ensure TPA is registered in `TPA_MASTER`:

```sql
-- Check if TPA exists
SELECT * FROM TPA_MASTER WHERE TPA_CODE = 'provider_a';

-- Add new TPA if needed
CALL add_tpa('provider_a', 'Provider A Healthcare', 'Dental claims provider');
```

### 2. Verify File Format

**CSV Requirements:**
- UTF-8 or Latin-1 encoding
- Header row with column names
- Comma-separated (other delimiters auto-detected)
- No special characters in header names (use underscores)

**Excel Requirements:**
- `.xlsx` or `.xls` format
- First row contains headers
- Data starts on row 2
- All sheets will be processed

### 3. Check File Size

- **Recommended**: < 100 MB per file
- **Maximum**: 5 GB per file (Snowflake limit)
- For large files, consider splitting into smaller batches

## After Uploading

### 1. Verify File Upload

```sql
-- List files in @SRC stage
LIST @SRC;

-- List files for specific TPA
LIST @SRC/provider_a/;

-- Check file in processing queue
SELECT * FROM file_processing_queue 
WHERE file_name LIKE '%your-file-name%';
```

### 2. Monitor Processing

```sql
-- View processing status
SELECT * FROM v_processing_status_summary;

-- View recent activity
SELECT * FROM v_recent_processing_activity 
WHERE tpa = 'provider_a';

-- Check for errors
SELECT * FROM v_failed_files 
WHERE tpa = 'provider_a';
```

### 3. Verify Data Load

```sql
-- Check raw data table
SELECT * FROM RAW_DATA_TABLE 
WHERE TPA = 'provider_a' 
  AND FILE_NAME = 'your-file-name.csv'
LIMIT 10;

-- Count records
SELECT COUNT(*) FROM RAW_DATA_TABLE 
WHERE TPA = 'provider_a' 
  AND FILE_NAME = 'your-file-name.csv';
```

## Troubleshooting

### Issue: File not discovered

**Symptoms:**
- File uploaded but not in `file_processing_queue`

**Solutions:**
1. Check file is in correct TPA folder: `LIST @SRC/provider_a/;`
2. Manually trigger discovery: `EXECUTE TASK discover_files_task;`
3. Wait for next scheduled discovery (every 60 minutes)

### Issue: File processing failed

**Symptoms:**
- File status is `FAILED` in queue
- Error message in `file_processing_queue.error_message`

**Solutions:**
1. Check error message:
   ```sql
   SELECT error_message FROM file_processing_queue 
   WHERE file_name = 'problem-file.csv';
   ```

2. Common errors and fixes:
   - **"Invalid TPA"**: Register TPA in `TPA_MASTER`
   - **"Parsing error"**: Check file format (encoding, delimiters)
   - **"Permission denied"**: Check role permissions

3. Reprocess after fixing:
   ```sql
   UPDATE file_processing_queue
   SET status = 'PENDING', retry_count = 0, error_message = NULL
   WHERE file_name = 'problem-file.csv';
   
   CALL process_queued_files();
   ```

### Issue: TPA not recognized

**Symptoms:**
- File uploaded but TPA extraction fails

**Solutions:**
1. Verify TPA folder structure: `@SRC/provider_a/file.csv` (not `@SRC/file.csv`)
2. Check TPA code matches `TPA_MASTER`: 
   ```sql
   SELECT * FROM TPA_MASTER WHERE TPA_CODE = 'provider_a';
   ```
3. Add TPA if missing:
   ```sql
   CALL add_tpa('provider_a', 'Provider A Healthcare', 'Description');
   ```

### Issue: Duplicate records

**Symptoms:**
- Same data loaded multiple times

**Explanation:**
- Bronze layer uses MERGE with `(FILE_NAME, FILE_ROW_NUMBER)` as unique key
- Uploading same file twice will NOT create duplicates
- Re-uploading with different filename WILL create duplicates

**Prevention:**
- Use consistent file naming convention
- Include date in filename (e.g., `claims-20240301.csv`)
- Check existing files before uploading: `LIST @SRC/provider_a/;`

## Best Practices

### File Naming

Use descriptive, consistent naming:

```
Good:
- claims-20240301.csv
- members-provider-a-20240301.csv
- eligibility-2024-Q1.xlsx

Bad:
- data.csv (too generic)
- file123.csv (not descriptive)
- claims (no extension)
```

### Batch Uploads

For large datasets:

1. **Split into smaller files** (< 100 MB each)
2. **Upload in batches** (10-20 files at a time)
3. **Monitor processing** between batches
4. **Use date-based naming** for tracking

Example:
```
claims-20240301-part1.csv
claims-20240301-part2.csv
claims-20240301-part3.csv
```

### Scheduling

For regular uploads:

1. **Daily uploads**: Upload files at consistent time (e.g., 6 AM)
2. **Wait for processing**: Allow 1-2 hours for processing
3. **Verify completion**: Check processing status before next upload
4. **Archive source files**: Keep local copies for 30 days

### Data Quality

Before uploading:

1. **Validate data**: Check for missing required fields
2. **Remove duplicates**: Deduplicate at source if possible
3. **Standardize formats**: Consistent date formats, codes, etc.
4. **Test with sample**: Upload small sample file first

## Automation

### Automated Upload Script

```bash
#!/bin/bash
# upload_to_bronze.sh

TPA="provider_a"
SOURCE_DIR="/path/to/data"
DATE=$(date +%Y%m%d)

# Upload files to Snowflake
snowsql -q "PUT file://${SOURCE_DIR}/*.csv @SRC/${TPA}/ AUTO_COMPRESS=FALSE;"

# Trigger discovery
snowsql -q "EXECUTE TASK discover_files_task;"

# Wait and check status
sleep 60
snowsql -q "SELECT * FROM v_processing_status_summary WHERE tpa = '${TPA}';"
```

### Scheduled Upload (cron)

```bash
# Add to crontab for daily upload at 6 AM
0 6 * * * /path/to/upload_to_bronze.sh >> /var/log/bronze_upload.log 2>&1
```

## Sample Data

Sample files are provided in `sample_data/claims_data/`:

```
sample_data/claims_data/
├── provider_a/
│   └── dental-claims-20240301.csv
├── provider_b/
│   └── medical-claims-20240115.csv
├── provider_c/
│   └── medical-claims-20240215.xlsx
├── provider_d/
│   └── medical-claims-20240315.xlsx
└── provider_e/
    └── pharmacy-claims-20240201.csv
```

**To upload sample data:**

```bash
# Via React UI (recommended)
# 1. Open Bronze Ingestion Pipeline app
# 2. Select TPA (e.g., provider_a)
# 3. Upload corresponding file from sample_data/claims_data/provider_a/

# Via SnowSQL
snowsql -q "PUT file://sample_data/claims_data/provider_a/*.csv @SRC/provider_a/ AUTO_COMPRESS=FALSE;"
```

## Related Documentation

- [Bronze README](README.md) - Bronze layer overview
- [User Guide](../docs/USER_GUIDE.md) - Complete usage guide
- [TPA Complete Guide](../docs/guides/TPA_COMPLETE_GUIDE.md) - TPA architecture

---

**Version**: 1.0  
**Last Updated**: January 15, 2026  
**Status**: ✅ Complete
