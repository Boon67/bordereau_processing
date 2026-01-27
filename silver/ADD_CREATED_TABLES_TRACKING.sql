-- ============================================
-- Add Created Tables Tracking
-- ============================================
-- Purpose: Add tracking table for user-created data tables
-- This distinguishes data tables from system tables
-- ============================================

-- ============================================
-- CONFIGURATION
-- ============================================

SET DATABASE_NAME = '$DATABASE_NAME';
SET SILVER_SCHEMA_NAME = '$SILVER_SCHEMA_NAME';
SET SNOWFLAKE_ROLE = '$SNOWFLAKE_ROLE';

USE ROLE IDENTIFIER($SNOWFLAKE_ROLE);
USE DATABASE IDENTIFIER($DATABASE_NAME);
USE SCHEMA IDENTIFIER($SILVER_SCHEMA_NAME);

-- ============================================
-- CREATE TRACKING TABLE
-- ============================================

CREATE HYBRID TABLE IF NOT EXISTS created_tables (
    table_id NUMBER(38,0) AUTOINCREMENT PRIMARY KEY,
    physical_table_name VARCHAR(500) NOT NULL UNIQUE,
    schema_table_name VARCHAR(500) NOT NULL,
    tpa VARCHAR(500) NOT NULL,
    created_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    created_by VARCHAR(500) DEFAULT CURRENT_USER(),
    description VARCHAR(5000),
    active BOOLEAN DEFAULT TRUE,
    INDEX idx_created_tables_tpa (tpa),
    INDEX idx_created_tables_schema (schema_table_name),
    INDEX idx_created_tables_active (active)
)
COMMENT = 'Tracks user-created Silver data tables. Used to distinguish data tables from system tables.';

-- ============================================
-- BACKFILL EXISTING TABLES (if any)
-- ============================================
-- This will populate the tracking table with any existing data tables
-- that match the pattern {TPA}_{TABLE_NAME}

-- Note: Manual backfill recommended for existing tables
-- The regex patterns below are best-effort and may need manual correction
-- For PROVIDER_A_DENTAL_CLAIMS, it should extract:
--   TPA: provider_a
--   SCHEMA_TABLE: DENTAL_CLAIMS

INSERT INTO created_tables (physical_table_name, schema_table_name, tpa, description, created_timestamp)
SELECT 
    t.table_name as physical_table_name,
    -- Try to match against known schema names from target_schemas
    COALESCE(
        (SELECT DISTINCT ts.table_name 
         FROM target_schemas ts 
         WHERE t.table_name LIKE '%' || ts.table_name
         LIMIT 1),
        'UNKNOWN'
    ) as schema_table_name,
    -- Try to match against known TPAs from tpa_registry
    COALESCE(
        (SELECT LOWER(tr.tpa_code)
         FROM BRONZE.tpa_registry tr
         WHERE t.table_name LIKE UPPER(tr.tpa_code) || '_%'
         LIMIT 1),
        'unknown'
    ) as tpa,
    'Backfilled from existing table - verify TPA and schema mapping' as description,
    t.created as created_timestamp
FROM INFORMATION_SCHEMA.TABLES t
WHERE t.table_schema = $SILVER_SCHEMA_NAME
  AND t.table_type = 'BASE TABLE'
  -- Exclude known system tables
  AND t.table_name NOT IN (
      'TARGET_SCHEMAS', 
      'FIELD_MAPPINGS', 
      'TRANSFORMATION_RULES', 
      'SILVER_PROCESSING_LOG',
      'CREATED_TABLES',
      'DATA_QUALITY_METRICS',
      'QUARANTINE_RECORDS',
      'PROCESSING_WATERMARKS',
      'LLM_PROMPT_TEMPLATES'
  )
  -- Only include tables that contain an underscore (likely TPA_TABLE format)
  AND t.table_name LIKE '%\_%'
  -- Don't insert duplicates
  AND NOT EXISTS (
      SELECT 1 FROM created_tables ct WHERE ct.physical_table_name = t.table_name
  );

-- ============================================
-- VERIFICATION
-- ============================================

SELECT 'Created tables tracking table added successfully' AS status;

SELECT 
    COUNT(*) as tracked_tables_count,
    COUNT(DISTINCT tpa) as unique_tpas
FROM created_tables
WHERE active = TRUE;

SELECT * FROM created_tables ORDER BY created_timestamp DESC;
