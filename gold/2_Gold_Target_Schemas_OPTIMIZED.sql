-- ============================================
-- GOLD LAYER TARGET SCHEMAS - OPTIMIZED VERSION
-- ============================================
-- This version uses batch INSERT instead of individual CALL statements
-- Performance improvement: ~50-100x faster
-- ============================================

USE ROLE SYSADMIN;
USE DATABASE &{DATABASE_NAME};
USE SCHEMA &{GOLD_SCHEMA_NAME};

-- ============================================
-- BATCH INSERT ALL FIELDS AT ONCE
-- ============================================
-- This is MUCH faster than 69 individual CALL statements

INSERT INTO target_fields (
    schema_id, field_name, data_type, field_order, is_nullable,
    description, business_definition, calculation_logic,
    is_key, is_measure, is_dimension
)
SELECT 
    ts.schema_id,
    f.field_name,
    f.data_type,
    f.field_order,
    f.is_nullable,
    f.description,
    f.business_definition,
    f.calculation_logic,
    f.is_key,
    f.is_measure,
    f.is_dimension
FROM target_schemas ts
CROSS JOIN (
    -- CLAIMS_ANALYTICS fields (18 fields)
    SELECT 'CLAIMS_ANALYTICS' as table_name, 'claim_analytics_id' as field_name, 'NUMBER(38,0)' as data_type, 1 as field_order, FALSE as is_nullable, 'Unique identifier' as description, 'Primary key for analytics record' as business_definition, NULL as calculation_logic, TRUE as is_key, FALSE as is_measure, FALSE as is_dimension
    UNION ALL SELECT 'CLAIMS_ANALYTICS', 'tpa', 'VARCHAR(100)', 2, FALSE, 'Third Party Administrator', 'TPA identifier', NULL, FALSE, FALSE, TRUE
    UNION ALL SELECT 'CLAIMS_ANALYTICS', 'claim_year', 'NUMBER(4,0)', 3, FALSE, 'Claim year', 'Year of claim service', NULL, FALSE, FALSE, TRUE
    UNION ALL SELECT 'CLAIMS_ANALYTICS', 'claim_month', 'NUMBER(2,0)', 4, FALSE, 'Claim month', 'Month of claim service', NULL, FALSE, FALSE, TRUE
    UNION ALL SELECT 'CLAIMS_ANALYTICS', 'claim_type', 'VARCHAR(50)', 5, FALSE, 'Claim type', 'Medical, Dental, or Pharmacy', NULL, FALSE, FALSE, TRUE
    UNION ALL SELECT 'CLAIMS_ANALYTICS', 'provider_id', 'VARCHAR(100)', 6, TRUE, 'Provider identifier', 'Unique provider ID', NULL, FALSE, FALSE, TRUE
    UNION ALL SELECT 'CLAIMS_ANALYTICS', 'provider_name', 'VARCHAR(500)', 7, TRUE, 'Provider name', 'Name of healthcare provider', NULL, FALSE, FALSE, TRUE
    UNION ALL SELECT 'CLAIMS_ANALYTICS', 'provider_specialty', 'VARCHAR(200)', 8, TRUE, 'Provider specialty', 'Medical specialty of provider', NULL, FALSE, FALSE, TRUE
    UNION ALL SELECT 'CLAIMS_ANALYTICS', 'member_count', 'NUMBER(18,0)', 9, FALSE, 'Member count', 'Number of unique members', NULL, FALSE, TRUE, FALSE
    UNION ALL SELECT 'CLAIMS_ANALYTICS', 'claim_count', 'NUMBER(18,0)', 10, FALSE, 'Claim count', 'Total number of claims', NULL, FALSE, TRUE, FALSE
    UNION ALL SELECT 'CLAIMS_ANALYTICS', 'total_billed_amount', 'NUMBER(18,2)', 11, FALSE, 'Total billed', 'Sum of billed amounts', NULL, FALSE, TRUE, FALSE
    UNION ALL SELECT 'CLAIMS_ANALYTICS', 'total_allowed_amount', 'NUMBER(18,2)', 12, FALSE, 'Total allowed', 'Sum of allowed amounts', NULL, FALSE, TRUE, FALSE
    UNION ALL SELECT 'CLAIMS_ANALYTICS', 'total_paid_amount', 'NUMBER(18,2)', 13, FALSE, 'Total paid', 'Sum of paid amounts', NULL, FALSE, TRUE, FALSE
    UNION ALL SELECT 'CLAIMS_ANALYTICS', 'avg_billed_per_claim', 'NUMBER(18,2)', 14, FALSE, 'Avg billed per claim', 'Average billed amount per claim', NULL, FALSE, TRUE, FALSE
    UNION ALL SELECT 'CLAIMS_ANALYTICS', 'avg_paid_per_claim', 'NUMBER(18,2)', 15, FALSE, 'Avg paid per claim', 'Average paid amount per claim', NULL, FALSE, TRUE, FALSE
    UNION ALL SELECT 'CLAIMS_ANALYTICS', 'discount_rate', 'NUMBER(18,4)', 16, FALSE, 'Discount rate', '(Billed - Paid) / Billed', NULL, FALSE, TRUE, FALSE
    UNION ALL SELECT 'CLAIMS_ANALYTICS', 'created_at', 'TIMESTAMP_NTZ', 17, FALSE, 'Record created timestamp', 'When record was created', NULL, FALSE, FALSE, FALSE
    UNION ALL SELECT 'CLAIMS_ANALYTICS', 'updated_at', 'TIMESTAMP_NTZ', 18, FALSE, 'Record updated timestamp', 'When record was last updated', NULL, FALSE, FALSE, FALSE
    
    -- MEMBER_360 fields (18 fields)
    UNION ALL SELECT 'MEMBER_360', 'member_360_id', 'NUMBER(38,0)', 1, FALSE, 'Unique identifier', 'Primary key', NULL, TRUE, FALSE, FALSE
    UNION ALL SELECT 'MEMBER_360', 'tpa', 'VARCHAR(100)', 2, FALSE, 'TPA identifier', 'Third Party Administrator', NULL, FALSE, FALSE, TRUE
    UNION ALL SELECT 'MEMBER_360', 'member_id', 'VARCHAR(100)', 3, FALSE, 'Member identifier', 'Unique member ID', NULL, FALSE, FALSE, TRUE
    UNION ALL SELECT 'MEMBER_360', 'member_name', 'VARCHAR(500)', 4, TRUE, 'Member name', 'Full name of member', NULL, FALSE, FALSE, TRUE
    UNION ALL SELECT 'MEMBER_360', 'date_of_birth', 'DATE', 5, TRUE, 'Date of birth', 'Member birth date', NULL, FALSE, FALSE, TRUE
    UNION ALL SELECT 'MEMBER_360', 'age', 'NUMBER(3,0)', 6, TRUE, 'Age', 'Current age in years', NULL, FALSE, FALSE, TRUE
    UNION ALL SELECT 'MEMBER_360', 'gender', 'VARCHAR(20)', 7, TRUE, 'Gender', 'Member gender', NULL, FALSE, FALSE, TRUE
    UNION ALL SELECT 'MEMBER_360', 'state', 'VARCHAR(50)', 8, TRUE, 'State', 'State of residence', NULL, FALSE, FALSE, TRUE
    UNION ALL SELECT 'MEMBER_360', 'enrollment_date', 'DATE', 9, TRUE, 'Enrollment date', 'Date member enrolled', NULL, FALSE, FALSE, TRUE
    UNION ALL SELECT 'MEMBER_360', 'total_claims', 'NUMBER(18,0)', 10, FALSE, 'Total claims', 'Lifetime claim count', NULL, FALSE, TRUE, FALSE
    UNION ALL SELECT 'MEMBER_360', 'total_paid', 'NUMBER(18,2)', 11, FALSE, 'Total paid', 'Lifetime paid amount', NULL, FALSE, TRUE, FALSE
    UNION ALL SELECT 'MEMBER_360', 'medical_claims', 'NUMBER(18,0)', 12, FALSE, 'Medical claims', 'Count of medical claims', NULL, FALSE, TRUE, FALSE
    UNION ALL SELECT 'MEMBER_360', 'dental_claims', 'NUMBER(18,0)', 13, FALSE, 'Dental claims', 'Count of dental claims', NULL, FALSE, TRUE, FALSE
    UNION ALL SELECT 'MEMBER_360', 'pharmacy_claims', 'NUMBER(18,0)', 14, FALSE, 'Pharmacy claims', 'Count of pharmacy claims', NULL, FALSE, TRUE, FALSE
    UNION ALL SELECT 'MEMBER_360', 'last_claim_date', 'DATE', 15, TRUE, 'Last claim date', 'Most recent claim service date', NULL, FALSE, FALSE, FALSE
    UNION ALL SELECT 'MEMBER_360', 'risk_score', 'NUMBER(18,4)', 16, TRUE, 'Risk score', 'Member risk score', NULL, FALSE, TRUE, FALSE
    UNION ALL SELECT 'MEMBER_360', 'created_at', 'TIMESTAMP_NTZ', 17, FALSE, 'Record created', 'Creation timestamp', NULL, FALSE, FALSE, FALSE
    UNION ALL SELECT 'MEMBER_360', 'updated_at', 'TIMESTAMP_NTZ', 18, FALSE, 'Record updated', 'Last update timestamp', NULL, FALSE, FALSE, FALSE
    
    -- PROVIDER_PERFORMANCE fields (17 fields)
    UNION ALL SELECT 'PROVIDER_PERFORMANCE', 'provider_perf_id', 'NUMBER(38,0)', 1, FALSE, 'Unique identifier', 'Primary key', NULL, TRUE, FALSE, FALSE
    UNION ALL SELECT 'PROVIDER_PERFORMANCE', 'tpa', 'VARCHAR(100)', 2, FALSE, 'TPA identifier', 'Third Party Administrator', NULL, FALSE, FALSE, TRUE
    UNION ALL SELECT 'PROVIDER_PERFORMANCE', 'provider_id', 'VARCHAR(100)', 3, FALSE, 'Provider ID', 'Unique provider identifier', NULL, FALSE, FALSE, TRUE
    UNION ALL SELECT 'PROVIDER_PERFORMANCE', 'provider_name', 'VARCHAR(500)', 4, TRUE, 'Provider name', 'Name of provider', NULL, FALSE, FALSE, TRUE
    UNION ALL SELECT 'PROVIDER_PERFORMANCE', 'provider_specialty', 'VARCHAR(200)', 5, TRUE, 'Specialty', 'Provider specialty', NULL, FALSE, FALSE, TRUE
    UNION ALL SELECT 'PROVIDER_PERFORMANCE', 'provider_type', 'VARCHAR(100)', 6, TRUE, 'Provider type', 'Individual or Facility', NULL, FALSE, FALSE, TRUE
    UNION ALL SELECT 'PROVIDER_PERFORMANCE', 'measurement_period', 'VARCHAR(50)', 7, FALSE, 'Measurement period', 'Period for metrics (e.g., 2024-Q1)', NULL, FALSE, FALSE, TRUE
    UNION ALL SELECT 'PROVIDER_PERFORMANCE', 'unique_members', 'NUMBER(18,0)', 8, FALSE, 'Unique members', 'Count of unique members served', NULL, FALSE, TRUE, FALSE
    UNION ALL SELECT 'PROVIDER_PERFORMANCE', 'total_claims', 'NUMBER(18,0)', 9, FALSE, 'Total claims', 'Total claim count', NULL, FALSE, TRUE, FALSE
    UNION ALL SELECT 'PROVIDER_PERFORMANCE', 'total_paid', 'NUMBER(18,2)', 10, FALSE, 'Total paid', 'Total paid amount', NULL, FALSE, TRUE, FALSE
    UNION ALL SELECT 'PROVIDER_PERFORMANCE', 'avg_cost_per_member', 'NUMBER(18,2)', 11, FALSE, 'Avg cost per member', 'Average cost per member', NULL, FALSE, TRUE, FALSE
    UNION ALL SELECT 'PROVIDER_PERFORMANCE', 'avg_cost_per_claim', 'NUMBER(18,2)', 12, FALSE, 'Avg cost per claim', 'Average cost per claim', NULL, FALSE, TRUE, FALSE
    UNION ALL SELECT 'PROVIDER_PERFORMANCE', 'discount_rate', 'NUMBER(18,4)', 13, FALSE, 'Discount rate', 'Average discount rate', NULL, FALSE, TRUE, FALSE
    UNION ALL SELECT 'PROVIDER_PERFORMANCE', 'readmission_rate', 'NUMBER(18,4)', 14, TRUE, 'Readmission rate', '30-day readmission rate', NULL, FALSE, TRUE, FALSE
    UNION ALL SELECT 'PROVIDER_PERFORMANCE', 'quality_score', 'NUMBER(18,4)', 15, TRUE, 'Quality score', 'Composite quality score', NULL, FALSE, TRUE, FALSE
    UNION ALL SELECT 'PROVIDER_PERFORMANCE', 'created_at', 'TIMESTAMP_NTZ', 16, FALSE, 'Record created', 'Creation timestamp', NULL, FALSE, FALSE, FALSE
    UNION ALL SELECT 'PROVIDER_PERFORMANCE', 'updated_at', 'TIMESTAMP_NTZ', 17, FALSE, 'Record updated', 'Last update timestamp', NULL, FALSE, FALSE, FALSE
    
    -- FINANCIAL_SUMMARY fields (16 fields)
    UNION ALL SELECT 'FINANCIAL_SUMMARY', 'financial_id', 'NUMBER(38,0)', 1, FALSE, 'Unique identifier', 'Primary key', NULL, TRUE, FALSE, FALSE
    UNION ALL SELECT 'FINANCIAL_SUMMARY', 'tpa', 'VARCHAR(100)', 2, FALSE, 'TPA identifier', 'Third Party Administrator', NULL, FALSE, FALSE, TRUE
    UNION ALL SELECT 'FINANCIAL_SUMMARY', 'fiscal_year', 'NUMBER(4,0)', 3, FALSE, 'Fiscal year', 'Fiscal year', NULL, FALSE, FALSE, TRUE
    UNION ALL SELECT 'FINANCIAL_SUMMARY', 'fiscal_month', 'NUMBER(2,0)', 4, FALSE, 'Fiscal month', 'Fiscal month', NULL, FALSE, FALSE, TRUE
    UNION ALL SELECT 'FINANCIAL_SUMMARY', 'fiscal_quarter', 'NUMBER(1,0)', 5, FALSE, 'Fiscal quarter', 'Fiscal quarter (1-4)', NULL, FALSE, FALSE, TRUE
    UNION ALL SELECT 'FINANCIAL_SUMMARY', 'claim_type', 'VARCHAR(50)', 6, TRUE, 'Claim type', 'Medical, Dental, Pharmacy, or ALL', NULL, FALSE, FALSE, TRUE
    UNION ALL SELECT 'FINANCIAL_SUMMARY', 'total_billed', 'NUMBER(18,2)', 7, FALSE, 'Total billed', 'Sum of billed amounts', NULL, FALSE, TRUE, FALSE
    UNION ALL SELECT 'FINANCIAL_SUMMARY', 'total_allowed', 'NUMBER(18,2)', 8, FALSE, 'Total allowed', 'Sum of allowed amounts', NULL, FALSE, TRUE, FALSE
    UNION ALL SELECT 'FINANCIAL_SUMMARY', 'total_paid', 'NUMBER(18,2)', 9, FALSE, 'Total paid', 'Sum of paid amounts', NULL, FALSE, TRUE, FALSE
    UNION ALL SELECT 'FINANCIAL_SUMMARY', 'total_member_responsibility', 'NUMBER(18,2)', 10, FALSE, 'Member responsibility', 'Total member cost share', NULL, FALSE, TRUE, FALSE
    UNION ALL SELECT 'FINANCIAL_SUMMARY', 'claim_count', 'NUMBER(18,0)', 11, FALSE, 'Claim count', 'Total number of claims', NULL, FALSE, TRUE, FALSE
    UNION ALL SELECT 'FINANCIAL_SUMMARY', 'member_count', 'NUMBER(18,0)', 12, FALSE, 'Member count', 'Unique member count', NULL, FALSE, TRUE, FALSE
    UNION ALL SELECT 'FINANCIAL_SUMMARY', 'pmpm', 'NUMBER(18,2)', 13, FALSE, 'PMPM', 'Per Member Per Month cost', NULL, FALSE, TRUE, FALSE
    UNION ALL SELECT 'FINANCIAL_SUMMARY', 'medical_loss_ratio', 'NUMBER(18,4)', 14, TRUE, 'MLR', 'Medical Loss Ratio', NULL, FALSE, TRUE, FALSE
    UNION ALL SELECT 'FINANCIAL_SUMMARY', 'created_at', 'TIMESTAMP_NTZ', 15, FALSE, 'Record created', 'Creation timestamp', NULL, FALSE, FALSE, FALSE
    UNION ALL SELECT 'FINANCIAL_SUMMARY', 'updated_at', 'TIMESTAMP_NTZ', 16, FALSE, 'Record updated', 'Last update timestamp', NULL, FALSE, FALSE, FALSE
) f
WHERE ts.table_name = f.table_name
  AND ts.tpa = 'ALL';

-- Verify the insert
SELECT 
    ts.table_name,
    COUNT(*) as field_count
FROM target_schemas ts
JOIN target_fields tf ON ts.schema_id = tf.schema_id
WHERE ts.tpa = 'ALL'
GROUP BY ts.table_name
ORDER BY ts.table_name;
