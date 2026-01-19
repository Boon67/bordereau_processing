-- ============================================
-- GOLD LAYER TARGET SCHEMAS
-- ============================================
-- Purpose: Define Gold layer target table structures
-- 
-- This script creates target table definitions for:
--   1. Claims Analytics (aggregated claims data)
--   2. Member 360 (comprehensive member view)
--   3. Provider Performance (provider metrics)
--   4. Financial Summary (financial analytics)
-- ============================================

-- ============================================
-- CONFIGURATION
-- ============================================

-- SET DATABASE_NAME (passed via -D parameter)
-- SET GOLD_SCHEMA_NAME (passed via -D parameter)

-- Using SYSADMIN role

USE ROLE SYSADMIN;
USE DATABASE &{DATABASE_NAME};
USE SCHEMA &{GOLD_SCHEMA_NAME};

-- ============================================
-- HELPER PROCEDURE: Create Target Schema
-- ============================================

CREATE OR REPLACE PROCEDURE create_gold_target_schema(
    p_table_name VARCHAR,
    p_tpa VARCHAR,
    p_description VARCHAR,
    p_business_owner VARCHAR DEFAULT 'Data Analytics Team',
    p_refresh_frequency VARCHAR DEFAULT 'DAILY',
    p_retention_days NUMBER DEFAULT 2555
)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
BEGIN
    -- Use MERGE to handle existing records
    MERGE INTO target_schemas AS t
    USING (
        SELECT 
            :p_table_name AS table_name,
            :p_tpa AS tpa,
            :p_description AS description,
            :p_business_owner AS business_owner,
            'CONFIDENTIAL' AS data_classification,
            :p_refresh_frequency AS refresh_frequency,
            :p_retention_days AS retention_days,
            TRUE AS is_active
    ) AS s
    ON t.table_name = s.table_name AND t.tpa = s.tpa
    WHEN MATCHED THEN
        UPDATE SET
            t.description = s.description,
            t.business_owner = s.business_owner,
            t.refresh_frequency = s.refresh_frequency,
            t.retention_days = s.retention_days,
            t.updated_at = CURRENT_TIMESTAMP()
    WHEN NOT MATCHED THEN
        INSERT (table_name, tpa, description, business_owner, data_classification, refresh_frequency, retention_days, is_active)
        VALUES (s.table_name, s.tpa, s.description, s.business_owner, s.data_classification, s.refresh_frequency, s.retention_days, s.is_active);

    RETURN 'Target schema created/updated: ' || :p_table_name || ' for TPA: ' || :p_tpa;
END;
$$;

-- ============================================
-- HELPER PROCEDURE: Add Target Field
-- ============================================

CREATE OR REPLACE PROCEDURE add_gold_target_field(
    p_table_name VARCHAR,
    p_tpa VARCHAR,
    p_field_name VARCHAR,
    p_data_type VARCHAR,
    p_field_order NUMBER,
    p_is_nullable BOOLEAN DEFAULT TRUE,
    p_description VARCHAR DEFAULT NULL,
    p_business_definition VARCHAR DEFAULT NULL,
    p_is_key BOOLEAN DEFAULT FALSE,
    p_is_measure BOOLEAN DEFAULT FALSE,
    p_is_dimension BOOLEAN DEFAULT FALSE
)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    v_schema_id NUMBER;
BEGIN
    -- Get schema_id
    SELECT schema_id INTO :v_schema_id
    FROM target_schemas
    WHERE table_name = :p_table_name AND tpa = :p_tpa;

    -- Use MERGE to handle existing fields
    MERGE INTO target_fields AS t
    USING (
        SELECT
            :v_schema_id AS schema_id,
            :p_field_name AS field_name,
            :p_data_type AS data_type,
            :p_field_order AS field_order,
            :p_is_nullable AS is_nullable,
            :p_description AS description,
            :p_business_definition AS business_definition,
            :p_is_key AS is_key,
            :p_is_measure AS is_measure,
            :p_is_dimension AS is_dimension
    ) AS s
    ON t.schema_id = s.schema_id AND t.field_name = s.field_name
    WHEN MATCHED THEN
        UPDATE SET
            t.data_type = s.data_type,
            t.field_order = s.field_order,
            t.is_nullable = s.is_nullable,
            t.description = s.description,
            t.business_definition = s.business_definition,
            t.is_key = s.is_key,
            t.is_measure = s.is_measure,
            t.is_dimension = s.is_dimension,
            t.updated_at = CURRENT_TIMESTAMP()
    WHEN NOT MATCHED THEN
        INSERT (schema_id, field_name, data_type, field_order, is_nullable, description, business_definition, is_key, is_measure, is_dimension)
        VALUES (s.schema_id, s.field_name, s.data_type, s.field_order, s.is_nullable, s.description, s.business_definition, s.is_key, s.is_measure, s.is_dimension);

    RETURN 'Field added/updated: ' || :p_field_name;
END;
$$;

-- ============================================
-- TARGET SCHEMA 1: CLAIMS_ANALYTICS
-- ============================================
-- Aggregated claims data for analytics and reporting

CALL create_gold_target_schema(
    'CLAIMS_ANALYTICS',
    'ALL',
    'Aggregated claims data with key metrics and dimensions for analytics',
    'Claims Analytics Team',
    'DAILY',
    2555
);

-- Define fields for CLAIMS_ANALYTICS
CALL add_gold_target_field('CLAIMS_ANALYTICS', 'ALL', 'claim_analytics_id', 'NUMBER(38,0)', 1, FALSE, 'Unique identifier', 'Primary key for analytics record', TRUE, FALSE, FALSE);
CALL add_gold_target_field('CLAIMS_ANALYTICS', 'ALL', 'tpa', 'VARCHAR(100)', 2, FALSE, 'Third Party Administrator', 'TPA identifier', FALSE, FALSE, TRUE);
CALL add_gold_target_field('CLAIMS_ANALYTICS', 'ALL', 'claim_year', 'NUMBER(4,0)', 3, FALSE, 'Claim year', 'Year of claim service', FALSE, FALSE, TRUE);
CALL add_gold_target_field('CLAIMS_ANALYTICS', 'ALL', 'claim_month', 'NUMBER(2,0)', 4, FALSE, 'Claim month', 'Month of claim service', FALSE, FALSE, TRUE);
CALL add_gold_target_field('CLAIMS_ANALYTICS', 'ALL', 'claim_type', 'VARCHAR(50)', 5, FALSE, 'Claim type', 'Medical, Dental, or Pharmacy', FALSE, FALSE, TRUE);
CALL add_gold_target_field('CLAIMS_ANALYTICS', 'ALL', 'provider_id', 'VARCHAR(100)', 6, TRUE, 'Provider identifier', 'Unique provider ID', FALSE, FALSE, TRUE);
CALL add_gold_target_field('CLAIMS_ANALYTICS', 'ALL', 'provider_name', 'VARCHAR(500)', 7, TRUE, 'Provider name', 'Name of healthcare provider', FALSE, FALSE, TRUE);
CALL add_gold_target_field('CLAIMS_ANALYTICS', 'ALL', 'provider_specialty', 'VARCHAR(200)', 8, TRUE, 'Provider specialty', 'Medical specialty of provider', FALSE, FALSE, TRUE);
CALL add_gold_target_field('CLAIMS_ANALYTICS', 'ALL', 'member_count', 'NUMBER(18,0)', 9, FALSE, 'Member count', 'Number of unique members', FALSE, TRUE, FALSE);
CALL add_gold_target_field('CLAIMS_ANALYTICS', 'ALL', 'claim_count', 'NUMBER(18,0)', 10, FALSE, 'Claim count', 'Total number of claims', FALSE, TRUE, FALSE);
CALL add_gold_target_field('CLAIMS_ANALYTICS', 'ALL', 'total_billed_amount', 'NUMBER(18,2)', 11, FALSE, 'Total billed', 'Sum of billed amounts', FALSE, TRUE, FALSE);
CALL add_gold_target_field('CLAIMS_ANALYTICS', 'ALL', 'total_allowed_amount', 'NUMBER(18,2)', 12, FALSE, 'Total allowed', 'Sum of allowed amounts', FALSE, TRUE, FALSE);
CALL add_gold_target_field('CLAIMS_ANALYTICS', 'ALL', 'total_paid_amount', 'NUMBER(18,2)', 13, FALSE, 'Total paid', 'Sum of paid amounts', FALSE, TRUE, FALSE);
CALL add_gold_target_field('CLAIMS_ANALYTICS', 'ALL', 'avg_billed_per_claim', 'NUMBER(18,2)', 14, FALSE, 'Avg billed per claim', 'Average billed amount per claim', FALSE, TRUE, FALSE);
CALL add_gold_target_field('CLAIMS_ANALYTICS', 'ALL', 'avg_paid_per_claim', 'NUMBER(18,2)', 15, FALSE, 'Avg paid per claim', 'Average paid amount per claim', FALSE, TRUE, FALSE);
CALL add_gold_target_field('CLAIMS_ANALYTICS', 'ALL', 'discount_rate', 'NUMBER(18,4)', 16, FALSE, 'Discount rate', '(Billed - Paid) / Billed', FALSE, TRUE, FALSE);
CALL add_gold_target_field('CLAIMS_ANALYTICS', 'ALL', 'created_at', 'TIMESTAMP_NTZ', 17, FALSE, 'Record created timestamp', 'When record was created', FALSE, FALSE, FALSE);
CALL add_gold_target_field('CLAIMS_ANALYTICS', 'ALL', 'updated_at', 'TIMESTAMP_NTZ', 18, FALSE, 'Record updated timestamp', 'When record was last updated', FALSE, FALSE, FALSE);

-- ============================================
-- TARGET SCHEMA 2: MEMBER_360
-- ============================================
-- Comprehensive member view with all relevant data

CALL create_gold_target_schema(
    'MEMBER_360',
    'ALL',
    'Comprehensive 360-degree view of member data including demographics and utilization',
    'Member Analytics Team',
    'DAILY',
    2555
);

-- Define fields for MEMBER_360
CALL add_gold_target_field('MEMBER_360', 'ALL', 'member_360_id', 'NUMBER(38,0)', 1, FALSE, 'Unique identifier', 'Primary key', TRUE, FALSE, FALSE);
CALL add_gold_target_field('MEMBER_360', 'ALL', 'tpa', 'VARCHAR(100)', 2, FALSE, 'TPA identifier', 'Third Party Administrator', FALSE, FALSE, TRUE);
CALL add_gold_target_field('MEMBER_360', 'ALL', 'member_id', 'VARCHAR(100)', 3, FALSE, 'Member identifier', 'Unique member ID', FALSE, FALSE, TRUE);
CALL add_gold_target_field('MEMBER_360', 'ALL', 'member_name', 'VARCHAR(500)', 4, TRUE, 'Member name', 'Full name of member', FALSE, FALSE, TRUE);
CALL add_gold_target_field('MEMBER_360', 'ALL', 'date_of_birth', 'DATE', 5, TRUE, 'Date of birth', 'Member birth date', FALSE, FALSE, TRUE);
CALL add_gold_target_field('MEMBER_360', 'ALL', 'age', 'NUMBER(3,0)', 6, TRUE, 'Age', 'Current age in years', FALSE, FALSE, TRUE);
CALL add_gold_target_field('MEMBER_360', 'ALL', 'gender', 'VARCHAR(20)', 7, TRUE, 'Gender', 'Member gender', FALSE, FALSE, TRUE);
CALL add_gold_target_field('MEMBER_360', 'ALL', 'state', 'VARCHAR(50)', 8, TRUE, 'State', 'State of residence', FALSE, FALSE, TRUE);
CALL add_gold_target_field('MEMBER_360', 'ALL', 'enrollment_date', 'DATE', 9, TRUE, 'Enrollment date', 'Date member enrolled', FALSE, FALSE, TRUE);
CALL add_gold_target_field('MEMBER_360', 'ALL', 'total_claims', 'NUMBER(18,0)', 10, FALSE, 'Total claims', 'Lifetime claim count', FALSE, TRUE, FALSE);
CALL add_gold_target_field('MEMBER_360', 'ALL', 'total_paid', 'NUMBER(18,2)', 11, FALSE, 'Total paid', 'Lifetime paid amount', FALSE, TRUE, FALSE);
CALL add_gold_target_field('MEMBER_360', 'ALL', 'medical_claims', 'NUMBER(18,0)', 12, FALSE, 'Medical claims', 'Count of medical claims', FALSE, TRUE, FALSE);
CALL add_gold_target_field('MEMBER_360', 'ALL', 'dental_claims', 'NUMBER(18,0)', 13, FALSE, 'Dental claims', 'Count of dental claims', FALSE, TRUE, FALSE);
CALL add_gold_target_field('MEMBER_360', 'ALL', 'pharmacy_claims', 'NUMBER(18,0)', 14, FALSE, 'Pharmacy claims', 'Count of pharmacy claims', FALSE, TRUE, FALSE);
CALL add_gold_target_field('MEMBER_360', 'ALL', 'last_claim_date', 'DATE', 15, TRUE, 'Last claim date', 'Most recent claim service date', FALSE, FALSE, FALSE);
CALL add_gold_target_field('MEMBER_360', 'ALL', 'risk_score', 'NUMBER(18,4)', 16, TRUE, 'Risk score', 'Member risk score', FALSE, TRUE, FALSE);
CALL add_gold_target_field('MEMBER_360', 'ALL', 'created_at', 'TIMESTAMP_NTZ', 17, FALSE, 'Record created', 'Creation timestamp', FALSE, FALSE, FALSE);
CALL add_gold_target_field('MEMBER_360', 'ALL', 'updated_at', 'TIMESTAMP_NTZ', 18, FALSE, 'Record updated', 'Last update timestamp', FALSE, FALSE, FALSE);

-- ============================================
-- TARGET SCHEMA 3: PROVIDER_PERFORMANCE
-- ============================================
-- Provider performance metrics and KPIs

CALL create_gold_target_schema(
    'PROVIDER_PERFORMANCE',
    'ALL',
    'Provider performance metrics including utilization, cost, and quality indicators',
    'Provider Network Team',
    'WEEKLY',
    2555
);

-- Define fields for PROVIDER_PERFORMANCE
CALL add_gold_target_field('PROVIDER_PERFORMANCE', 'ALL', 'provider_perf_id', 'NUMBER(38,0)', 1, FALSE, 'Unique identifier', 'Primary key', TRUE, FALSE, FALSE);
CALL add_gold_target_field('PROVIDER_PERFORMANCE', 'ALL', 'tpa', 'VARCHAR(100)', 2, FALSE, 'TPA identifier', 'Third Party Administrator', FALSE, FALSE, TRUE);
CALL add_gold_target_field('PROVIDER_PERFORMANCE', 'ALL', 'provider_id', 'VARCHAR(100)', 3, FALSE, 'Provider ID', 'Unique provider identifier', FALSE, FALSE, TRUE);
CALL add_gold_target_field('PROVIDER_PERFORMANCE', 'ALL', 'provider_name', 'VARCHAR(500)', 4, TRUE, 'Provider name', 'Name of provider', FALSE, FALSE, TRUE);
CALL add_gold_target_field('PROVIDER_PERFORMANCE', 'ALL', 'provider_specialty', 'VARCHAR(200)', 5, TRUE, 'Specialty', 'Provider specialty', FALSE, FALSE, TRUE);
CALL add_gold_target_field('PROVIDER_PERFORMANCE', 'ALL', 'provider_type', 'VARCHAR(100)', 6, TRUE, 'Provider type', 'Individual or Facility', FALSE, FALSE, TRUE);
CALL add_gold_target_field('PROVIDER_PERFORMANCE', 'ALL', 'measurement_period', 'VARCHAR(50)', 7, FALSE, 'Measurement period', 'Period for metrics (e.g., 2024-Q1)', FALSE, FALSE, TRUE);
CALL add_gold_target_field('PROVIDER_PERFORMANCE', 'ALL', 'unique_members', 'NUMBER(18,0)', 8, FALSE, 'Unique members', 'Count of unique members served', FALSE, TRUE, FALSE);
CALL add_gold_target_field('PROVIDER_PERFORMANCE', 'ALL', 'total_claims', 'NUMBER(18,0)', 9, FALSE, 'Total claims', 'Total claim count', FALSE, TRUE, FALSE);
CALL add_gold_target_field('PROVIDER_PERFORMANCE', 'ALL', 'total_paid', 'NUMBER(18,2)', 10, FALSE, 'Total paid', 'Total paid amount', FALSE, TRUE, FALSE);
CALL add_gold_target_field('PROVIDER_PERFORMANCE', 'ALL', 'avg_cost_per_member', 'NUMBER(18,2)', 11, FALSE, 'Avg cost per member', 'Average cost per member', FALSE, TRUE, FALSE);
CALL add_gold_target_field('PROVIDER_PERFORMANCE', 'ALL', 'avg_cost_per_claim', 'NUMBER(18,2)', 12, FALSE, 'Avg cost per claim', 'Average cost per claim', FALSE, TRUE, FALSE);
CALL add_gold_target_field('PROVIDER_PERFORMANCE', 'ALL', 'discount_rate', 'NUMBER(18,4)', 13, FALSE, 'Discount rate', 'Average discount rate', FALSE, TRUE, FALSE);
CALL add_gold_target_field('PROVIDER_PERFORMANCE', 'ALL', 'readmission_rate', 'NUMBER(18,4)', 14, TRUE, 'Readmission rate', '30-day readmission rate', FALSE, TRUE, FALSE);
CALL add_gold_target_field('PROVIDER_PERFORMANCE', 'ALL', 'quality_score', 'NUMBER(18,4)', 15, TRUE, 'Quality score', 'Composite quality score', FALSE, TRUE, FALSE);
CALL add_gold_target_field('PROVIDER_PERFORMANCE', 'ALL', 'created_at', 'TIMESTAMP_NTZ', 16, FALSE, 'Record created', 'Creation timestamp', FALSE, FALSE, FALSE);
CALL add_gold_target_field('PROVIDER_PERFORMANCE', 'ALL', 'updated_at', 'TIMESTAMP_NTZ', 17, FALSE, 'Record updated', 'Last update timestamp', FALSE, FALSE, FALSE);

-- ============================================
-- TARGET SCHEMA 4: FINANCIAL_SUMMARY
-- ============================================
-- Financial summary and analytics

CALL create_gold_target_schema(
    'FINANCIAL_SUMMARY',
    'ALL',
    'Financial summary with revenue, costs, and key financial metrics',
    'Finance Team',
    'MONTHLY',
    2555
);

-- Define fields for FINANCIAL_SUMMARY
CALL add_gold_target_field('FINANCIAL_SUMMARY', 'ALL', 'financial_id', 'NUMBER(38,0)', 1, FALSE, 'Unique identifier', 'Primary key', TRUE, FALSE, FALSE);
CALL add_gold_target_field('FINANCIAL_SUMMARY', 'ALL', 'tpa', 'VARCHAR(100)', 2, FALSE, 'TPA identifier', 'Third Party Administrator', FALSE, FALSE, TRUE);
CALL add_gold_target_field('FINANCIAL_SUMMARY', 'ALL', 'fiscal_year', 'NUMBER(4,0)', 3, FALSE, 'Fiscal year', 'Fiscal year', FALSE, FALSE, TRUE);
CALL add_gold_target_field('FINANCIAL_SUMMARY', 'ALL', 'fiscal_month', 'NUMBER(2,0)', 4, FALSE, 'Fiscal month', 'Fiscal month', FALSE, FALSE, TRUE);
CALL add_gold_target_field('FINANCIAL_SUMMARY', 'ALL', 'fiscal_quarter', 'NUMBER(1,0)', 5, FALSE, 'Fiscal quarter', 'Fiscal quarter (1-4)', FALSE, FALSE, TRUE);
CALL add_gold_target_field('FINANCIAL_SUMMARY', 'ALL', 'claim_type', 'VARCHAR(50)', 6, TRUE, 'Claim type', 'Medical, Dental, Pharmacy, or ALL', FALSE, FALSE, TRUE);
CALL add_gold_target_field('FINANCIAL_SUMMARY', 'ALL', 'total_billed', 'NUMBER(18,2)', 7, FALSE, 'Total billed', 'Sum of billed amounts', FALSE, TRUE, FALSE);
CALL add_gold_target_field('FINANCIAL_SUMMARY', 'ALL', 'total_allowed', 'NUMBER(18,2)', 8, FALSE, 'Total allowed', 'Sum of allowed amounts', FALSE, TRUE, FALSE);
CALL add_gold_target_field('FINANCIAL_SUMMARY', 'ALL', 'total_paid', 'NUMBER(18,2)', 9, FALSE, 'Total paid', 'Sum of paid amounts', FALSE, TRUE, FALSE);
CALL add_gold_target_field('FINANCIAL_SUMMARY', 'ALL', 'total_member_responsibility', 'NUMBER(18,2)', 10, FALSE, 'Member responsibility', 'Total member cost share', FALSE, TRUE, FALSE);
CALL add_gold_target_field('FINANCIAL_SUMMARY', 'ALL', 'claim_count', 'NUMBER(18,0)', 11, FALSE, 'Claim count', 'Total number of claims', FALSE, TRUE, FALSE);
CALL add_gold_target_field('FINANCIAL_SUMMARY', 'ALL', 'member_count', 'NUMBER(18,0)', 12, FALSE, 'Member count', 'Unique member count', FALSE, TRUE, FALSE);
CALL add_gold_target_field('FINANCIAL_SUMMARY', 'ALL', 'pmpm', 'NUMBER(18,2)', 13, FALSE, 'PMPM', 'Per Member Per Month cost', FALSE, TRUE, FALSE);
CALL add_gold_target_field('FINANCIAL_SUMMARY', 'ALL', 'medical_loss_ratio', 'NUMBER(18,4)', 14, TRUE, 'MLR', 'Medical Loss Ratio', FALSE, TRUE, FALSE);
CALL add_gold_target_field('FINANCIAL_SUMMARY', 'ALL', 'created_at', 'TIMESTAMP_NTZ', 15, FALSE, 'Record created', 'Creation timestamp', FALSE, FALSE, FALSE);
CALL add_gold_target_field('FINANCIAL_SUMMARY', 'ALL', 'updated_at', 'TIMESTAMP_NTZ', 16, FALSE, 'Record updated', 'Last update timestamp', FALSE, FALSE, FALSE);

-- ============================================
-- CREATE ACTUAL TARGET TABLES
-- ============================================

CREATE OR REPLACE PROCEDURE create_gold_target_table(p_table_name VARCHAR, p_tpa VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    v_create_sql VARCHAR;
    v_field_list VARCHAR;
    v_cluster_keys VARCHAR;
BEGIN
    -- Build field list from target_fields
    SELECT LISTAGG(
        field_name || ' ' || data_type || 
        CASE WHEN NOT is_nullable THEN ' NOT NULL' ELSE '' END,
        ',\n    '
    ) WITHIN GROUP (ORDER BY field_order)
    INTO v_field_list
    FROM target_fields tf
    JOIN target_schemas ts ON tf.schema_id = ts.schema_id
    WHERE ts.table_name = :p_table_name AND ts.tpa = :p_tpa;
    
    -- Determine clustering keys based on table type
    v_cluster_keys := CASE :p_table_name
        WHEN 'CLAIMS_ANALYTICS' THEN ' CLUSTER BY (tpa, claim_year, claim_month, claim_type)'
        WHEN 'MEMBER_360' THEN ' CLUSTER BY (tpa, member_id)'
        WHEN 'PROVIDER_PERFORMANCE' THEN ' CLUSTER BY (tpa, provider_id, measurement_period)'
        WHEN 'FINANCIAL_SUMMARY' THEN ' CLUSTER BY (tpa, fiscal_year, fiscal_month)'
        ELSE ''
    END;
    
    -- Create table with clustering
    v_create_sql := 'CREATE TABLE IF NOT EXISTS ' || :p_table_name || '_' || :p_tpa || ' (\n    ' || 
                    v_field_list || '\n)' || v_cluster_keys;
    
    EXECUTE IMMEDIATE v_create_sql;
    
    RETURN 'Table created: ' || :p_table_name || '_' || :p_tpa || ' with clustering';
END;
$$;

-- Create tables for ALL TPA (generic/shared tables) with clustering keys
CALL create_gold_target_table('CLAIMS_ANALYTICS', 'ALL');
CALL create_gold_target_table('MEMBER_360', 'ALL');
CALL create_gold_target_table('PROVIDER_PERFORMANCE', 'ALL');
CALL create_gold_target_table('FINANCIAL_SUMMARY', 'ALL');

-- ============================================
-- COMPLETION MESSAGE
-- ============================================

SELECT 'Gold Target Schemas Created' AS status,
       COUNT(*) AS schema_count
FROM target_schemas;

SELECT 'Gold Target Fields Created' AS status,
       COUNT(*) AS field_count
FROM target_fields;
