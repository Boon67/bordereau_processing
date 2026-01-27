-- ============================================
-- MIGRATION: TPA-Agnostic Schema Design
-- ============================================
-- Purpose: Convert target_schemas from TPA-specific to TPA-agnostic
--
-- OLD DESIGN:
--   - Schemas are duplicated per TPA (DENTAL_CLAIMS x 5 TPAs = 5 copies)
--   - Unique constraint: (table_name, column_name, tpa)
--   - Tables created: PROVIDER_A_DENTAL_CLAIMS
--
-- NEW DESIGN:
--   - Schemas are shared across all TPAs (DENTAL_CLAIMS x 1 = 1 definition)
--   - Unique constraint: (table_name, column_name)
--   - Tables created: PROVIDER_A_DENTAL_CLAIMS (same, but from shared schema)
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
-- STEP 1: Backup existing data
-- ============================================

CREATE OR REPLACE TABLE target_schemas_backup AS
SELECT * FROM target_schemas;

SELECT 'Backed up ' || COUNT(*) || ' schema records' AS status
FROM target_schemas_backup;

-- ============================================
-- STEP 2: Create new TPA-agnostic table
-- ============================================

CREATE OR REPLACE HYBRID TABLE target_schemas_new (
    schema_id NUMBER(38,0) AUTOINCREMENT PRIMARY KEY,
    table_name VARCHAR(500) NOT NULL,
    column_name VARCHAR(500) NOT NULL,
    data_type VARCHAR(200) NOT NULL,
    nullable BOOLEAN DEFAULT TRUE,
    default_value VARCHAR(1000),
    description VARCHAR(5000),
    created_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    created_by VARCHAR(500) DEFAULT CURRENT_USER(),
    active BOOLEAN DEFAULT TRUE,
    CONSTRAINT uk_target_schemas_new UNIQUE (table_name, column_name),
    INDEX idx_target_schemas_table (table_name)
)
COMMENT = 'TPA-agnostic target table definitions. Schemas are shared across all TPAs. Tables are created per TPA (e.g., PROVIDER_A_DENTAL_CLAIMS).';

-- ============================================
-- STEP 3: Migrate data (consolidate duplicates)
-- ============================================
-- Keep only one definition per (table_name, column_name)
-- Use provider_a as the source since it's the primary test TPA

INSERT INTO target_schemas_new (
    table_name,
    column_name,
    data_type,
    nullable,
    default_value,
    description,
    created_timestamp,
    updated_timestamp,
    created_by,
    active
)
SELECT DISTINCT
    table_name,
    column_name,
    data_type,
    nullable,
    default_value,
    description,
    MIN(created_timestamp) AS created_timestamp,
    MAX(updated_timestamp) AS updated_timestamp,
    created_by,
    active
FROM target_schemas_backup
WHERE tpa = 'provider_a'  -- Use provider_a as the canonical source
GROUP BY 
    table_name,
    column_name,
    data_type,
    nullable,
    default_value,
    description,
    created_by,
    active;

-- Verify migration
SELECT 
    'Migration complete' AS status,
    (SELECT COUNT(*) FROM target_schemas_backup) AS old_count,
    (SELECT COUNT(*) FROM target_schemas_new) AS new_count,
    (SELECT COUNT(DISTINCT table_name) FROM target_schemas_new) AS unique_tables;

-- ============================================
-- STEP 4: Replace old table with new
-- ============================================

DROP TABLE target_schemas;
ALTER TABLE target_schemas_new RENAME TO target_schemas;

-- ============================================
-- STEP 5: Verify new structure
-- ============================================

SELECT 
    table_name,
    COUNT(*) AS column_count
FROM target_schemas
WHERE active = TRUE
GROUP BY table_name
ORDER BY table_name;

-- Show sample
SELECT * FROM target_schemas LIMIT 10;

-- ============================================
-- STEP 6: Update dependent procedures
-- ============================================
-- The create_silver_table procedure needs to be updated
-- to not filter by TPA when querying target_schemas

SELECT 'Migration complete! Update create_silver_table procedure next.' AS next_step;
