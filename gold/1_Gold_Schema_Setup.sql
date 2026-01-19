-- ============================================
-- GOLD LAYER SCHEMA AND METADATA TABLES
-- ============================================
-- Purpose: Create Gold layer stages and metadata tables
-- 
-- This script creates:
--   1. Stages (2): @GOLD_STAGE, @GOLD_CONFIG
--   2. Metadata Tables (8): All include TPA dimension
--
-- Gold Layer Purpose:
--   - Final business-ready data layer
--   - Aggregations and analytics-ready tables
--   - Business rules and quality checks
--   - Conformed dimensions and facts
-- ============================================

-- ============================================
-- CONFIGURATION
-- ============================================

-- SET DATABASE_NAME (passed via -D parameter)
-- SET SILVER_SCHEMA_NAME (passed via -D parameter)
-- SET GOLD_SCHEMA_NAME (passed via -D parameter)

-- Set role and context
-- Using SYSADMIN role

USE ROLE SYSADMIN;
USE DATABASE &{DATABASE_NAME};

-- ============================================
-- CREATE GOLD SCHEMA
-- ============================================

CREATE SCHEMA IF NOT EXISTS &{GOLD_SCHEMA_NAME}
    COMMENT = 'Gold Layer: Business-ready analytics data';

USE SCHEMA &{GOLD_SCHEMA_NAME};

-- ============================================
-- CREATE STAGES
-- ============================================

CREATE OR REPLACE STAGE GOLD_STAGE
    DIRECTORY = (ENABLE = TRUE)
    COMMENT = 'Final transformation and aggregation files';

CREATE OR REPLACE STAGE GOLD_CONFIG
    DIRECTORY = (ENABLE = TRUE)
    COMMENT = 'Gold layer configuration and business rules CSVs';

-- ============================================
-- METADATA TABLE 1: target_schemas (HYBRID TABLE)
-- ============================================
-- Defines the structure of Gold layer target tables
-- Each schema represents a business entity (e.g., CLAIMS_ANALYTICS, MEMBER_360)
-- Using HYBRID TABLE for fast lookups and point queries

CREATE HYBRID TABLE IF NOT EXISTS target_schemas (
    schema_id NUMBER(38,0) AUTOINCREMENT PRIMARY KEY,
    table_name VARCHAR(500) NOT NULL,
    tpa VARCHAR(100) NOT NULL,
    description VARCHAR(2000),
    business_owner VARCHAR(200),
    data_classification VARCHAR(50),
    refresh_frequency VARCHAR(50),
    retention_days NUMBER(10,0),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    created_by VARCHAR(200) DEFAULT CURRENT_USER(),
    updated_by VARCHAR(200) DEFAULT CURRENT_USER(),
    UNIQUE (table_name, tpa),
    INDEX idx_target_schemas_tpa (tpa),
    INDEX idx_target_schemas_active (is_active)
);

-- ============================================
-- METADATA TABLE 2: target_fields (HYBRID TABLE)
-- ============================================
-- Defines individual fields in Gold target tables
-- Using HYBRID TABLE for fast field lookups

CREATE HYBRID TABLE IF NOT EXISTS target_fields (
    field_id NUMBER(38,0) AUTOINCREMENT PRIMARY KEY,
    schema_id NUMBER(38,0) NOT NULL,
    field_name VARCHAR(500) NOT NULL,
    data_type VARCHAR(100) NOT NULL,
    field_order NUMBER(10,0),
    is_nullable BOOLEAN DEFAULT TRUE,
    default_value VARCHAR(500),
    description VARCHAR(2000),
    business_definition VARCHAR(2000),
    calculation_logic VARCHAR(4000),
    is_key BOOLEAN DEFAULT FALSE,
    is_measure BOOLEAN DEFAULT FALSE,
    is_dimension BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    FOREIGN KEY (schema_id) REFERENCES target_schemas(schema_id),
    UNIQUE (schema_id, field_name),
    INDEX idx_target_fields_schema (schema_id)
);

-- ============================================
-- METADATA TABLE 3: transformation_rules (HYBRID TABLE)
-- ============================================
-- Business rules and transformations for Gold layer
-- Using HYBRID TABLE for fast rule lookups during transformations

CREATE HYBRID TABLE IF NOT EXISTS transformation_rules (
    rule_id NUMBER(38,0) AUTOINCREMENT PRIMARY KEY,
    rule_name VARCHAR(500) NOT NULL,
    rule_type VARCHAR(100) NOT NULL, -- AGGREGATION, CALCULATION, DERIVATION, QUALITY_CHECK
    tpa VARCHAR(100) NOT NULL,
    source_table VARCHAR(500),
    target_table VARCHAR(500),
    rule_logic VARCHAR(4000) NOT NULL,
    rule_description VARCHAR(2000),
    business_justification VARCHAR(2000),
    priority NUMBER(10,0) DEFAULT 100,
    is_active BOOLEAN DEFAULT TRUE,
    execution_order NUMBER(10,0),
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    created_by VARCHAR(200) DEFAULT CURRENT_USER(),
    updated_by VARCHAR(200) DEFAULT CURRENT_USER(),
    UNIQUE (rule_name, tpa),
    INDEX idx_trans_rules_tpa (tpa),
    INDEX idx_trans_rules_type (rule_type),
    INDEX idx_trans_rules_active (is_active)
);

-- ============================================
-- METADATA TABLE 4: field_mappings (HYBRID TABLE)
-- ============================================
-- Maps Silver layer fields to Gold layer fields
-- Using HYBRID TABLE for fast mapping lookups during transformations

CREATE HYBRID TABLE IF NOT EXISTS field_mappings (
    mapping_id NUMBER(38,0) AUTOINCREMENT PRIMARY KEY,
    source_schema VARCHAR(100) NOT NULL DEFAULT 'SILVER',
    source_table VARCHAR(500) NOT NULL,
    source_field VARCHAR(500) NOT NULL,
    target_table VARCHAR(500) NOT NULL,
    target_field VARCHAR(500) NOT NULL,
    tpa VARCHAR(100) NOT NULL,
    transformation_logic VARCHAR(4000),
    aggregation_function VARCHAR(100), -- SUM, AVG, COUNT, MIN, MAX, FIRST, LAST
    group_by_fields VARCHAR(1000),
    filter_condition VARCHAR(2000),
    is_active BOOLEAN DEFAULT TRUE,
    priority NUMBER(10,0) DEFAULT 100,
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    UNIQUE (source_table, source_field, target_table, target_field, tpa),
    INDEX idx_field_mappings_tpa (tpa),
    INDEX idx_field_mappings_source (source_table),
    INDEX idx_field_mappings_target (target_table)
);

-- ============================================
-- METADATA TABLE 5: quality_rules (HYBRID TABLE)
-- ============================================
-- Data quality checks for Gold layer
-- Using HYBRID TABLE for fast quality rule lookups

CREATE HYBRID TABLE IF NOT EXISTS quality_rules (
    quality_rule_id NUMBER(38,0) AUTOINCREMENT PRIMARY KEY,
    rule_name VARCHAR(500) NOT NULL,
    rule_type VARCHAR(100) NOT NULL, -- COMPLETENESS, ACCURACY, CONSISTENCY, VALIDITY, TIMELINESS
    table_name VARCHAR(500) NOT NULL,
    tpa VARCHAR(100) NOT NULL,
    field_name VARCHAR(500),
    check_logic VARCHAR(4000) NOT NULL,
    threshold_value NUMBER(18,4),
    threshold_operator VARCHAR(20), -- >, <, >=, <=, =, !=
    severity VARCHAR(50) DEFAULT 'WARNING', -- CRITICAL, ERROR, WARNING, INFO
    action_on_failure VARCHAR(100), -- REJECT, FLAG, LOG, ALERT
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    UNIQUE (rule_name, table_name, tpa),
    INDEX idx_quality_rules_tpa (tpa),
    INDEX idx_quality_rules_table (table_name),
    INDEX idx_quality_rules_active (is_active)
);

-- ============================================
-- METADATA TABLE 6: processing_log
-- ============================================
-- Tracks Gold layer processing runs

CREATE TABLE IF NOT EXISTS processing_log (
    log_id NUMBER(38,0) AUTOINCREMENT PRIMARY KEY,
    run_id VARCHAR(100) NOT NULL,
    table_name VARCHAR(500) NOT NULL,
    tpa VARCHAR(100) NOT NULL,
    process_type VARCHAR(100) NOT NULL, -- TRANSFORMATION, AGGREGATION, QUALITY_CHECK
    status VARCHAR(50) NOT NULL, -- STARTED, IN_PROGRESS, COMPLETED, FAILED
    records_processed NUMBER(18,0),
    records_inserted NUMBER(18,0),
    records_updated NUMBER(18,0),
    records_rejected NUMBER(18,0),
    start_time TIMESTAMP_NTZ,
    end_time TIMESTAMP_NTZ,
    duration_seconds NUMBER(18,2),
    error_message VARCHAR(4000),
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- ============================================
-- METADATA TABLE 7: quality_check_results
-- ============================================
-- Stores results of quality checks

CREATE TABLE IF NOT EXISTS quality_check_results (
    check_id NUMBER(38,0) AUTOINCREMENT PRIMARY KEY,
    run_id VARCHAR(100) NOT NULL,
    quality_rule_id NUMBER(38,0) NOT NULL,
    table_name VARCHAR(500) NOT NULL,
    tpa VARCHAR(100) NOT NULL,
    check_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    records_checked NUMBER(18,0),
    records_passed NUMBER(18,0),
    records_failed NUMBER(18,0),
    pass_rate NUMBER(18,4),
    threshold_met BOOLEAN,
    status VARCHAR(50), -- PASSED, FAILED, WARNING
    details VARCHAR(4000)
    -- Note: Foreign keys only supported on hybrid tables
    -- quality_rule_id references quality_rules(quality_rule_id)
);

-- ============================================
-- METADATA TABLE 8: business_metrics (HYBRID TABLE)
-- ============================================
-- Tracks key business metrics and KPIs
-- Using HYBRID TABLE for fast metric lookups

CREATE HYBRID TABLE IF NOT EXISTS business_metrics (
    metric_id NUMBER(38,0) AUTOINCREMENT PRIMARY KEY,
    metric_name VARCHAR(500) NOT NULL,
    metric_category VARCHAR(100) NOT NULL, -- FINANCIAL, OPERATIONAL, CLINICAL, MEMBER
    tpa VARCHAR(100) NOT NULL,
    calculation_logic VARCHAR(4000) NOT NULL,
    source_tables VARCHAR(1000),
    refresh_frequency VARCHAR(50),
    metric_owner VARCHAR(200),
    description VARCHAR(2000),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    UNIQUE (metric_name, tpa),
    INDEX idx_business_metrics_tpa (tpa),
    INDEX idx_business_metrics_category (metric_category)
);

-- ============================================
-- NOTE: INDEXES AND CLUSTERING
-- ============================================
-- Hybrid tables (metadata tables above) have indexes defined inline
-- Standard tables (processing_log, quality_check_results) use clustering keys instead
-- Analytics tables (CLAIMS_ANALYTICS_ALL, etc.) will use clustering keys in their definitions

-- ============================================
-- GRANT PERMISSIONS
-- ============================================

-- Grant usage on schema
GRANT USAGE ON SCHEMA &{GOLD_SCHEMA_NAME} TO ROLE SYSADMIN;

-- Grant permissions on stages
GRANT READ, WRITE ON STAGE GOLD_STAGE TO ROLE SYSADMIN;
GRANT READ, WRITE ON STAGE GOLD_CONFIG TO ROLE SYSADMIN;

-- Grant permissions on all tables
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA &{GOLD_SCHEMA_NAME} 
    TO ROLE SYSADMIN;

-- Grant permissions on future tables
GRANT SELECT, INSERT, UPDATE, DELETE ON FUTURE TABLES IN SCHEMA &{GOLD_SCHEMA_NAME} 
    TO ROLE SYSADMIN;

-- ============================================
-- COMPLETION MESSAGE
-- ============================================

SELECT 'Gold Layer Schema Setup Complete' AS status,
       CURRENT_DATABASE() AS database_name,
       CURRENT_SCHEMA() AS schema_name,
       CURRENT_TIMESTAMP() AS completed_at;
