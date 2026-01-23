-- ============================================
-- Gold Layer - Target Schemas (BULK LOAD VERSION)
-- ============================================
-- This version uses bulk INSERT statements instead of
-- individual procedure calls for better performance
-- ============================================

USE DATABASE BORDEREAU_PROCESSING_PIPELINE;
USE SCHEMA GOLD;

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
-- TARGET SCHEMA 1: CLAIMS_ANALYTICS
-- ============================================

CALL create_gold_target_schema(
    'CLAIMS_ANALYTICS',
    'ALL',
    'Aggregated claims analytics with key metrics and dimensions',
    'Analytics Team',
    'DAILY',
    2555
);

-- Delete existing fields for CLAIMS_ANALYTICS if any (for idempotent re-runs)
DELETE FROM target_fields 
WHERE schema_id IN (
    SELECT schema_id FROM target_schemas 
    WHERE table_name = 'CLAIMS_ANALYTICS' AND tpa = 'ALL'
);

-- Bulk insert fields for CLAIMS_ANALYTICS
INSERT INTO target_fields (schema_id, field_name, data_type, field_order, is_nullable, description, is_key, is_measure, is_dimension)
SELECT 
    ts.schema_id,
    f.field_name,
    f.data_type,
    f.field_order,
    f.is_nullable,
    f.description,
    f.is_key,
    f.is_measure,
    f.is_dimension
FROM target_schemas ts
CROSS JOIN (
    SELECT 'claim_analytics_id' AS field_name, 'NUMBER(38,0)' AS data_type, 1 AS field_order, FALSE AS is_nullable, 'Primary key' AS description, TRUE AS is_key, FALSE AS is_measure, FALSE AS is_dimension
    UNION ALL SELECT 'tpa', 'VARCHAR(100)', 2, FALSE, 'Third Party Administrator', FALSE, FALSE, TRUE
    UNION ALL SELECT 'claim_year', 'NUMBER(4,0)', 3, FALSE, 'Year of claim', FALSE, FALSE, TRUE
    UNION ALL SELECT 'claim_month', 'NUMBER(2,0)', 4, FALSE, 'Month of claim', FALSE, FALSE, TRUE
    UNION ALL SELECT 'claim_type', 'VARCHAR(50)', 5, FALSE, 'Medical, Dental, Pharmacy', FALSE, FALSE, TRUE
    UNION ALL SELECT 'provider_specialty', 'VARCHAR(200)', 6, TRUE, 'Specialty of provider', FALSE, FALSE, TRUE
    UNION ALL SELECT 'diagnosis_category', 'VARCHAR(200)', 7, TRUE, 'High-level diagnosis grouping', FALSE, FALSE, TRUE
    UNION ALL SELECT 'claim_count', 'NUMBER(18,0)', 8, FALSE, 'Total number of claims', FALSE, TRUE, FALSE
    UNION ALL SELECT 'unique_members', 'NUMBER(18,0)', 9, FALSE, 'Count of unique members', FALSE, TRUE, FALSE
    UNION ALL SELECT 'total_billed', 'NUMBER(18,2)', 10, FALSE, 'Sum of billed amounts', FALSE, TRUE, FALSE
    UNION ALL SELECT 'total_allowed', 'NUMBER(18,2)', 11, FALSE, 'Sum of allowed amounts', FALSE, TRUE, FALSE
    UNION ALL SELECT 'total_paid', 'NUMBER(18,2)', 12, FALSE, 'Sum of paid amounts', FALSE, TRUE, FALSE
    UNION ALL SELECT 'avg_paid_per_claim', 'NUMBER(18,2)', 13, FALSE, 'Average paid amount per claim', FALSE, TRUE, FALSE
    UNION ALL SELECT 'avg_paid_per_member', 'NUMBER(18,2)', 14, FALSE, 'Average paid amount per member', FALSE, TRUE, FALSE
    UNION ALL SELECT 'created_at', 'TIMESTAMP_NTZ', 15, FALSE, 'Creation timestamp', FALSE, FALSE, FALSE
    UNION ALL SELECT 'updated_at', 'TIMESTAMP_NTZ', 16, FALSE, 'Last update timestamp', FALSE, FALSE, FALSE
) f
WHERE ts.table_name = 'CLAIMS_ANALYTICS' AND ts.tpa = 'ALL';

-- ============================================
-- TARGET SCHEMA 2: MEMBER_360
-- ============================================

CALL create_gold_target_schema(
    'MEMBER_360',
    'ALL',
    'Comprehensive member profile with demographics, utilization, and risk',
    'Member Services Team',
    'DAILY',
    2555
);

-- Delete existing fields for MEMBER_360 if any (for idempotent re-runs)
DELETE FROM target_fields 
WHERE schema_id IN (
    SELECT schema_id FROM target_schemas 
    WHERE table_name = 'MEMBER_360' AND tpa = 'ALL'
);

-- Bulk insert fields for MEMBER_360
INSERT INTO target_fields (schema_id, field_name, data_type, field_order, is_nullable, description, is_key, is_measure, is_dimension)
SELECT 
    ts.schema_id,
    f.field_name,
    f.data_type,
    f.field_order,
    f.is_nullable,
    f.description,
    f.is_key,
    f.is_measure,
    f.is_dimension
FROM target_schemas ts
CROSS JOIN (
    SELECT 'member_360_id' AS field_name, 'NUMBER(38,0)' AS data_type, 1 AS field_order, FALSE AS is_nullable, 'Primary key' AS description, TRUE AS is_key, FALSE AS is_measure, FALSE AS is_dimension
    UNION ALL SELECT 'tpa', 'VARCHAR(100)', 2, FALSE, 'Third Party Administrator', FALSE, FALSE, TRUE
    UNION ALL SELECT 'member_id', 'VARCHAR(100)', 3, FALSE, 'Unique member identifier', FALSE, FALSE, TRUE
    UNION ALL SELECT 'member_name', 'VARCHAR(500)', 4, TRUE, 'Full name of member', FALSE, FALSE, TRUE
    UNION ALL SELECT 'date_of_birth', 'DATE', 5, TRUE, 'Member date of birth', FALSE, FALSE, TRUE
    UNION ALL SELECT 'age', 'NUMBER(3,0)', 6, TRUE, 'Current age', FALSE, FALSE, TRUE
    UNION ALL SELECT 'gender', 'VARCHAR(20)', 7, TRUE, 'Member gender', FALSE, FALSE, TRUE
    UNION ALL SELECT 'enrollment_date', 'DATE', 8, TRUE, 'Date enrolled', FALSE, FALSE, TRUE
    UNION ALL SELECT 'termination_date', 'DATE', 9, TRUE, 'Date terminated', FALSE, FALSE, TRUE
    UNION ALL SELECT 'is_active', 'BOOLEAN', 10, FALSE, 'Currently active member', FALSE, FALSE, TRUE
    UNION ALL SELECT 'total_claims_ytd', 'NUMBER(18,0)', 11, FALSE, 'Total claims year-to-date', FALSE, TRUE, FALSE
    UNION ALL SELECT 'total_paid_ytd', 'NUMBER(18,2)', 12, FALSE, 'Total paid year-to-date', FALSE, TRUE, FALSE
    UNION ALL SELECT 'chronic_conditions', 'ARRAY', 13, TRUE, 'List of chronic conditions', FALSE, FALSE, FALSE
    UNION ALL SELECT 'primary_care_provider', 'VARCHAR(500)', 14, TRUE, 'Primary care provider name', FALSE, FALSE, TRUE
    UNION ALL SELECT 'last_visit_date', 'DATE', 15, TRUE, 'Date of last healthcare visit', FALSE, FALSE, FALSE
    UNION ALL SELECT 'risk_score', 'NUMBER(18,4)', 16, TRUE, 'Member risk score', FALSE, TRUE, FALSE
    UNION ALL SELECT 'created_at', 'TIMESTAMP_NTZ', 17, FALSE, 'Creation timestamp', FALSE, FALSE, FALSE
    UNION ALL SELECT 'updated_at', 'TIMESTAMP_NTZ', 18, FALSE, 'Last update timestamp', FALSE, FALSE, FALSE
) f
WHERE ts.table_name = 'MEMBER_360' AND ts.tpa = 'ALL';

-- ============================================
-- TARGET SCHEMA 3: PROVIDER_PERFORMANCE
-- ============================================

CALL create_gold_target_schema(
    'PROVIDER_PERFORMANCE',
    'ALL',
    'Provider performance metrics including utilization, cost, and quality indicators',
    'Provider Network Team',
    'WEEKLY',
    2555
);

-- Delete existing fields for PROVIDER_PERFORMANCE if any (for idempotent re-runs)
DELETE FROM target_fields 
WHERE schema_id IN (
    SELECT schema_id FROM target_schemas 
    WHERE table_name = 'PROVIDER_PERFORMANCE' AND tpa = 'ALL'
);

-- Bulk insert fields for PROVIDER_PERFORMANCE
INSERT INTO target_fields (schema_id, field_name, data_type, field_order, is_nullable, description, is_key, is_measure, is_dimension)
SELECT 
    ts.schema_id,
    f.field_name,
    f.data_type,
    f.field_order,
    f.is_nullable,
    f.description,
    f.is_key,
    f.is_measure,
    f.is_dimension
FROM target_schemas ts
CROSS JOIN (
    SELECT 'provider_perf_id' AS field_name, 'NUMBER(38,0)' AS data_type, 1 AS field_order, FALSE AS is_nullable, 'Primary key' AS description, TRUE AS is_key, FALSE AS is_measure, FALSE AS is_dimension
    UNION ALL SELECT 'tpa', 'VARCHAR(100)', 2, FALSE, 'Third Party Administrator', FALSE, FALSE, TRUE
    UNION ALL SELECT 'provider_id', 'VARCHAR(100)', 3, FALSE, 'Unique provider identifier', FALSE, FALSE, TRUE
    UNION ALL SELECT 'provider_name', 'VARCHAR(500)', 4, TRUE, 'Name of provider', FALSE, FALSE, TRUE
    UNION ALL SELECT 'provider_specialty', 'VARCHAR(200)', 5, TRUE, 'Provider specialty', FALSE, FALSE, TRUE
    UNION ALL SELECT 'provider_type', 'VARCHAR(100)', 6, TRUE, 'Individual or Facility', FALSE, FALSE, TRUE
    UNION ALL SELECT 'measurement_period', 'VARCHAR(50)', 7, FALSE, 'Period for metrics (e.g., 2024-Q1)', FALSE, FALSE, TRUE
    UNION ALL SELECT 'unique_members', 'NUMBER(18,0)', 8, FALSE, 'Count of unique members served', FALSE, TRUE, FALSE
    UNION ALL SELECT 'total_claims', 'NUMBER(18,0)', 9, FALSE, 'Total claim count', FALSE, TRUE, FALSE
    UNION ALL SELECT 'total_paid', 'NUMBER(18,2)', 10, FALSE, 'Total paid amount', FALSE, TRUE, FALSE
    UNION ALL SELECT 'avg_cost_per_member', 'NUMBER(18,2)', 11, FALSE, 'Average cost per member', FALSE, TRUE, FALSE
    UNION ALL SELECT 'avg_cost_per_claim', 'NUMBER(18,2)', 12, FALSE, 'Average cost per claim', FALSE, TRUE, FALSE
    UNION ALL SELECT 'discount_rate', 'NUMBER(18,4)', 13, FALSE, 'Average discount rate', FALSE, TRUE, FALSE
    UNION ALL SELECT 'readmission_rate', 'NUMBER(18,4)', 14, TRUE, '30-day readmission rate', FALSE, TRUE, FALSE
    UNION ALL SELECT 'quality_score', 'NUMBER(18,4)', 15, TRUE, 'Composite quality score', FALSE, TRUE, FALSE
    UNION ALL SELECT 'created_at', 'TIMESTAMP_NTZ', 16, FALSE, 'Creation timestamp', FALSE, FALSE, FALSE
    UNION ALL SELECT 'updated_at', 'TIMESTAMP_NTZ', 17, FALSE, 'Last update timestamp', FALSE, FALSE, FALSE
) f
WHERE ts.table_name = 'PROVIDER_PERFORMANCE' AND ts.tpa = 'ALL';

-- ============================================
-- TARGET SCHEMA 4: FINANCIAL_SUMMARY
-- ============================================

CALL create_gold_target_schema(
    'FINANCIAL_SUMMARY',
    'ALL',
    'Financial summary with revenue, costs, and key financial metrics',
    'Finance Team',
    'MONTHLY',
    2555
);

-- Delete existing fields for FINANCIAL_SUMMARY if any (for idempotent re-runs)
DELETE FROM target_fields 
WHERE schema_id IN (
    SELECT schema_id FROM target_schemas 
    WHERE table_name = 'FINANCIAL_SUMMARY' AND tpa = 'ALL'
);

-- Bulk insert fields for FINANCIAL_SUMMARY
INSERT INTO target_fields (schema_id, field_name, data_type, field_order, is_nullable, description, is_key, is_measure, is_dimension)
SELECT 
    ts.schema_id,
    f.field_name,
    f.data_type,
    f.field_order,
    f.is_nullable,
    f.description,
    f.is_key,
    f.is_measure,
    f.is_dimension
FROM target_schemas ts
CROSS JOIN (
    SELECT 'financial_id' AS field_name, 'NUMBER(38,0)' AS data_type, 1 AS field_order, FALSE AS is_nullable, 'Primary key' AS description, TRUE AS is_key, FALSE AS is_measure, FALSE AS is_dimension
    UNION ALL SELECT 'tpa', 'VARCHAR(100)', 2, FALSE, 'Third Party Administrator', FALSE, FALSE, TRUE
    UNION ALL SELECT 'fiscal_year', 'NUMBER(4,0)', 3, FALSE, 'Fiscal year', FALSE, FALSE, TRUE
    UNION ALL SELECT 'fiscal_month', 'NUMBER(2,0)', 4, FALSE, 'Fiscal month', FALSE, FALSE, TRUE
    UNION ALL SELECT 'fiscal_quarter', 'NUMBER(1,0)', 5, FALSE, 'Fiscal quarter (1-4)', FALSE, FALSE, TRUE
    UNION ALL SELECT 'claim_type', 'VARCHAR(50)', 6, TRUE, 'Medical, Dental, Pharmacy, or ALL', FALSE, FALSE, TRUE
    UNION ALL SELECT 'total_billed', 'NUMBER(18,2)', 7, FALSE, 'Sum of billed amounts', FALSE, TRUE, FALSE
    UNION ALL SELECT 'total_allowed', 'NUMBER(18,2)', 8, FALSE, 'Sum of allowed amounts', FALSE, TRUE, FALSE
    UNION ALL SELECT 'total_paid', 'NUMBER(18,2)', 9, FALSE, 'Sum of paid amounts', FALSE, TRUE, FALSE
    UNION ALL SELECT 'total_member_responsibility', 'NUMBER(18,2)', 10, FALSE, 'Total member cost share', FALSE, TRUE, FALSE
    UNION ALL SELECT 'claim_count', 'NUMBER(18,0)', 11, FALSE, 'Total number of claims', FALSE, TRUE, FALSE
    UNION ALL SELECT 'member_count', 'NUMBER(18,0)', 12, FALSE, 'Unique member count', FALSE, TRUE, FALSE
    UNION ALL SELECT 'pmpm', 'NUMBER(18,2)', 13, FALSE, 'Per Member Per Month cost', FALSE, TRUE, FALSE
    UNION ALL SELECT 'medical_loss_ratio', 'NUMBER(18,4)', 14, TRUE, 'Medical Loss Ratio', FALSE, TRUE, FALSE
    UNION ALL SELECT 'created_at', 'TIMESTAMP_NTZ', 15, FALSE, 'Creation timestamp', FALSE, FALSE, FALSE
    UNION ALL SELECT 'updated_at', 'TIMESTAMP_NTZ', 16, FALSE, 'Last update timestamp', FALSE, FALSE, FALSE
) f
WHERE ts.table_name = 'FINANCIAL_SUMMARY' AND ts.tpa = 'ALL';

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

-- ============================================
-- PERFORMANCE COMPARISON
-- ============================================
-- Old approach: 4 schema calls + 65 individual field calls = 69 procedure calls
-- New approach: 4 schema calls + 4 bulk inserts = 8 operations
-- Performance improvement: ~88% reduction in database round trips
-- ============================================
