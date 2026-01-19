-- ============================================
-- SILVER LAYER SCHEMA AND METADATA TABLES
-- ============================================
-- Purpose: Create Silver layer stages and metadata tables
-- 
-- This script creates:
--   1. Stages (2): @SILVER_STAGE, @SILVER_CONFIG
--   2. Metadata Tables (8): All include TPA dimension
--
-- TPA Architecture:
--   - All metadata tables include TPA as part of unique constraints
--   - Target tables are TPA-specific (e.g., CLAIMS_PROVIDER_A)
--   - Mappings and rules defined per TPA
-- ============================================

-- ============================================
-- CONFIGURATION
-- ============================================

SET DATABASE_NAME = '$DATABASE_NAME';
SET BRONZE_SCHEMA_NAME = '$BRONZE_SCHEMA_NAME';
SET SILVER_SCHEMA_NAME = '$SILVER_SCHEMA_NAME';

-- Set role and context
SET role_admin = $DATABASE_NAME || '_ADMIN';

USE ROLE IDENTIFIER($role_admin);
USE DATABASE IDENTIFIER($DATABASE_NAME);
USE SCHEMA IDENTIFIER($SILVER_SCHEMA_NAME);

-- ============================================
-- CREATE STAGES
-- ============================================

CREATE OR REPLACE STAGE SILVER_STAGE
    DIRECTORY = (ENABLE = TRUE)
    COMMENT = 'Intermediate transformation files';

CREATE OR REPLACE STAGE SILVER_CONFIG
    DIRECTORY = (ENABLE = TRUE)
    COMMENT = 'Mapping and rules configuration CSVs';


-- ============================================
-- METADATA TABLE 1: target_schemas (HYBRID TABLE)
-- ============================================
-- Using HYBRID TABLE for fast schema lookups during transformations

CREATE HYBRID TABLE IF NOT EXISTS target_schemas (
    schema_id NUMBER(38,0) AUTOINCREMENT PRIMARY KEY,
    table_name VARCHAR(500) NOT NULL,
    column_name VARCHAR(500) NOT NULL,
    tpa VARCHAR(500) NOT NULL,  -- REQUIRED
    data_type VARCHAR(200) NOT NULL,
    nullable BOOLEAN DEFAULT TRUE,
    default_value VARCHAR(1000),
    description VARCHAR(5000),
    created_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    created_by VARCHAR(500) DEFAULT CURRENT_USER(),
    active BOOLEAN DEFAULT TRUE,
    CONSTRAINT uk_target_schemas UNIQUE (table_name, column_name, tpa),
    INDEX idx_target_schemas_tpa (tpa),
    INDEX idx_target_schemas_table (table_name)
)
COMMENT = 'Dynamic target table definitions per TPA. Defines schema for Silver tables that will be created from Bronze data.';

-- ============================================
-- METADATA TABLE 2: field_mappings (HYBRID TABLE)
-- ============================================
-- Using HYBRID TABLE for fast mapping lookups during transformations

CREATE HYBRID TABLE IF NOT EXISTS field_mappings (
    mapping_id NUMBER(38,0) AUTOINCREMENT PRIMARY KEY,
    source_field VARCHAR(500) NOT NULL,
    source_table VARCHAR(500) DEFAULT 'RAW_DATA_TABLE',
    target_table VARCHAR(500) NOT NULL,
    target_column VARCHAR(500) NOT NULL,
    tpa VARCHAR(500) NOT NULL,  -- REQUIRED
    mapping_method VARCHAR(50),  -- MANUAL, ML_AUTO, LLM_CORTEX, SYSTEM
    transformation_logic VARCHAR(5000),
    confidence_score FLOAT,
    approved BOOLEAN DEFAULT FALSE,
    approved_by VARCHAR(500),
    approved_timestamp TIMESTAMP_NTZ,
    description VARCHAR(5000),
    created_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    created_by VARCHAR(500) DEFAULT CURRENT_USER(),
    active BOOLEAN DEFAULT TRUE,
    CONSTRAINT uk_field_mappings UNIQUE (source_field, source_table, target_table, target_column, tpa),
    INDEX idx_field_mappings_tpa (tpa),
    INDEX idx_field_mappings_target (target_table)
)
COMMENT = 'Bronze → Silver field mappings per TPA. Supports multiple mapping methods: MANUAL (CSV), ML_AUTO (pattern matching), LLM_CORTEX (AI-powered).';

-- ============================================
-- METADATA TABLE 3: transformation_rules (HYBRID TABLE)
-- ============================================
-- Using HYBRID TABLE for fast rule lookups during transformations

CREATE HYBRID TABLE IF NOT EXISTS transformation_rules (
    rule_id VARCHAR(100) NOT NULL,
    tpa VARCHAR(500) NOT NULL,  -- REQUIRED
    rule_name VARCHAR(500) NOT NULL,
    rule_type VARCHAR(50) NOT NULL,  -- DATA_QUALITY, BUSINESS_LOGIC, STANDARDIZATION, DEDUPLICATION, REFERENTIAL_INTEGRITY
    target_table VARCHAR(500),
    target_column VARCHAR(500),
    rule_logic VARCHAR(5000) NOT NULL,
    error_action VARCHAR(50) DEFAULT 'REJECT',  -- REJECT, QUARANTINE, FLAG, CORRECT
    priority NUMBER(38,0) DEFAULT 100,
    active BOOLEAN DEFAULT TRUE,
    description VARCHAR(5000),
    created_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    created_by VARCHAR(500) DEFAULT CURRENT_USER(),
    CONSTRAINT pk_transformation_rules PRIMARY KEY (rule_id, tpa),
    INDEX idx_transformation_rules_tpa (tpa),
    INDEX idx_transformation_rules_type (rule_type),
    INDEX idx_transformation_rules_active (active)
)
COMMENT = 'Data quality and business rules per TPA. Five rule types: DATA_QUALITY, BUSINESS_LOGIC, STANDARDIZATION, DEDUPLICATION, REFERENTIAL_INTEGRITY.';

-- ============================================
-- METADATA TABLE 4: silver_processing_log
-- ============================================

CREATE TABLE IF NOT EXISTS silver_processing_log (
    log_id NUMBER(38,0) AUTOINCREMENT PRIMARY KEY,
    batch_id VARCHAR(100) NOT NULL,
    tpa VARCHAR(500) NOT NULL,
    source_table VARCHAR(500),
    target_table VARCHAR(500),
    processing_type VARCHAR(50),  -- DISCOVERY, MAPPING, TRANSFORMATION, VALIDATION, PUBLISH
    status VARCHAR(50),  -- STARTED, IN_PROGRESS, SUCCESS, FAILED
    records_processed NUMBER(38,0),
    records_success NUMBER(38,0),
    records_failed NUMBER(38,0),
    start_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    end_timestamp TIMESTAMP_NTZ,
    duration_seconds NUMBER(38,0),
    error_message VARCHAR(5000),
    created_by VARCHAR(500) DEFAULT CURRENT_USER()
)
COMMENT = 'Transformation batch audit trail. Tracks all Silver processing activities with detailed metrics.';

-- ============================================
-- METADATA TABLE 5: data_quality_metrics
-- ============================================

CREATE TABLE IF NOT EXISTS data_quality_metrics (
    metric_id NUMBER(38,0) AUTOINCREMENT PRIMARY KEY,
    batch_id VARCHAR(100) NOT NULL,
    tpa VARCHAR(500) NOT NULL,
    target_table VARCHAR(500) NOT NULL,
    metric_name VARCHAR(500) NOT NULL,
    metric_value FLOAT,
    metric_threshold FLOAT,
    passed BOOLEAN,
    measured_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    description VARCHAR(5000)
)
COMMENT = 'Quality tracking per TPA and batch. Stores data quality metrics with pass/fail thresholds.';

-- ============================================
-- METADATA TABLE 6: quarantine_records
-- ============================================

CREATE TABLE IF NOT EXISTS quarantine_records (
    quarantine_id NUMBER(38,0) AUTOINCREMENT PRIMARY KEY,
    batch_id VARCHAR(100) NOT NULL,
    tpa VARCHAR(500) NOT NULL,
    source_table VARCHAR(500),
    target_table VARCHAR(500),
    record_data VARIANT,
    rule_id VARCHAR(100),
    rule_name VARCHAR(500),
    failure_reason VARCHAR(5000),
    quarantine_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    reprocessed BOOLEAN DEFAULT FALSE,
    reprocessed_timestamp TIMESTAMP_NTZ
)
COMMENT = 'Failed validation records. Stores records that failed transformation rules for review and reprocessing.';

-- ============================================
-- METADATA TABLE 7: processing_watermarks
-- ============================================

CREATE TABLE IF NOT EXISTS processing_watermarks (
    watermark_id NUMBER(38,0) AUTOINCREMENT PRIMARY KEY,
    source_table VARCHAR(500) NOT NULL,
    target_table VARCHAR(500) NOT NULL,
    tpa VARCHAR(500) NOT NULL,
    last_processed_id NUMBER(38,0),
    last_processed_timestamp TIMESTAMP_NTZ,
    updated_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT uk_watermarks UNIQUE (source_table, target_table, tpa)
)
COMMENT = 'Incremental processing state per TPA. Tracks last processed record for incremental transformations.';

-- ============================================
-- METADATA TABLE 8: llm_prompt_templates
-- ============================================

-- Using HYBRID TABLE for fast template lookups
CREATE HYBRID TABLE IF NOT EXISTS llm_prompt_templates (
    template_id VARCHAR(100) PRIMARY KEY,
    template_name VARCHAR(500) NOT NULL,
    template_text VARCHAR(10000) NOT NULL,
    model_name VARCHAR(100),
    description VARCHAR(5000),
    active BOOLEAN DEFAULT TRUE,
    created_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    created_by VARCHAR(500) DEFAULT CURRENT_USER(),
    INDEX idx_llm_templates_active (active)
)
COMMENT = 'LLM prompt templates for field mapping. Stores prompts used by Cortex AI for semantic field mapping.';

-- Insert default LLM prompt
MERGE INTO llm_prompt_templates t
USING (
    SELECT 
        'DEFAULT_FIELD_MAPPING' AS template_id,
        'Default Field Mapping Prompt' AS template_name,
        'You are a data mapping expert. Given the following source fields and target fields, suggest the best mappings.

Source Fields:
{source_fields}

Target Fields:
{target_fields}

Return a JSON array of mappings in this format:
[
  {
    "source_field": "SOURCE_FIELD_NAME",
    "target_field": "TABLE.COLUMN",
    "confidence": 0.95,
    "reasoning": "Explanation for this mapping"
  }
]

Only include mappings with confidence >= 0.7. Be conservative and accurate.' AS template_text,
        'llama3.1-70b' AS model_name,
        'Default prompt for LLM-based field mapping using Snowflake Cortex AI' AS description
) s
ON t.template_id = s.template_id
WHEN NOT MATCHED THEN INSERT (template_id, template_name, template_text, model_name, description)
    VALUES (s.template_id, s.template_name, s.template_text, s.model_name, s.description);

-- ============================================
-- CREATE VIEWS
-- ============================================

CREATE OR REPLACE VIEW v_silver_summary AS
SELECT 
    'Target Schemas' AS object_type,
    COUNT(DISTINCT table_name || '_' || tpa) AS count
FROM target_schemas
WHERE active = TRUE
UNION ALL
SELECT 
    'Field Mappings',
    COUNT(*)
FROM field_mappings
WHERE active = TRUE
UNION ALL
SELECT 
    'Transformation Rules',
    COUNT(*)
FROM transformation_rules
WHERE active = TRUE
UNION ALL
SELECT 
    'Processing Batches',
    COUNT(DISTINCT batch_id)
FROM silver_processing_log;

COMMENT ON VIEW v_silver_summary IS 'Summary of Silver layer metadata objects.';

-- ============================================
-- VERIFICATION
-- ============================================

SHOW STAGES IN SCHEMA IDENTIFIER($SILVER_SCHEMA_NAME);
SHOW TABLES IN SCHEMA IDENTIFIER($SILVER_SCHEMA_NAME);

SELECT 'Silver schema and metadata tables created successfully' AS status,
       (SELECT COUNT(*) FROM target_schemas) AS target_schemas_count,
       (SELECT COUNT(*) FROM field_mappings) AS field_mappings_count,
       (SELECT COUNT(*) FROM transformation_rules) AS transformation_rules_count;
