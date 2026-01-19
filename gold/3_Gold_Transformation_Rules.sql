-- ============================================
-- GOLD LAYER TRANSFORMATION RULES
-- ============================================
-- Purpose: Define transformation rules for Gold layer
-- 
-- This script creates transformation rules for:
--   1. Aggregations (claims analytics)
--   2. Calculations (derived metrics)
--   3. Quality checks (data validation)
--   4. Business rules (business logic)
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
-- TRANSFORMATION RULES FOR CLAIMS_ANALYTICS
-- ============================================

-- Rule 1: Aggregate claims by year, month, type, and provider
MERGE INTO transformation_rules AS t
USING (
    SELECT
        'AGGREGATE_CLAIMS_BY_PERIOD_PROVIDER' AS rule_name,
        'AGGREGATION' AS rule_type,
        'ALL' AS tpa,
        'SILVER.CLAIMS_*' AS source_table,
        'CLAIMS_ANALYTICS_ALL' AS target_table,
        'GROUP BY YEAR(service_date), MONTH(service_date), claim_type, provider_id' AS rule_logic,
        'Aggregate claims data by time period and provider' AS rule_description,
        'Enable trend analysis and provider performance tracking' AS business_justification,
        100 AS priority,
        1 AS execution_order
) AS s
ON t.rule_name = s.rule_name AND t.tpa = s.tpa
WHEN MATCHED THEN
    UPDATE SET
        t.rule_type = s.rule_type,
        t.source_table = s.source_table,
        t.target_table = s.target_table,
        t.rule_logic = s.rule_logic,
        t.rule_description = s.rule_description,
        t.business_justification = s.business_justification,
        t.priority = s.priority,
        t.execution_order = s.execution_order,
        t.updated_at = CURRENT_TIMESTAMP()
WHEN NOT MATCHED THEN
    INSERT (rule_name, rule_type, tpa, source_table, target_table, rule_logic, rule_description, business_justification, priority, execution_order)
    VALUES (s.rule_name, s.rule_type, s.tpa, s.source_table, s.target_table, s.rule_logic, s.rule_description, s.business_justification, s.priority, s.execution_order);

-- Rule 2: Calculate discount rate
MERGE INTO transformation_rules AS t
USING (
    SELECT
        'CALCULATE_DISCOUNT_RATE' AS rule_name,
        'CALCULATION' AS rule_type,
        'ALL' AS tpa,
        'CLAIMS_ANALYTICS_ALL' AS source_table,
        'CLAIMS_ANALYTICS_ALL' AS target_table,
        '(total_billed_amount - total_paid_amount) / NULLIF(total_billed_amount, 0)' AS rule_logic,
        'Calculate discount rate as percentage of billed amount' AS rule_description,
        'Track negotiated discounts and network performance' AS business_justification,
        100 AS priority,
        2 AS execution_order
) AS s
ON t.rule_name = s.rule_name AND t.tpa = s.tpa
WHEN MATCHED THEN
    UPDATE SET
        t.rule_type = s.rule_type,
        t.source_table = s.source_table,
        t.target_table = s.target_table,
        t.rule_logic = s.rule_logic,
        t.rule_description = s.rule_description,
        t.business_justification = s.business_justification,
        t.priority = s.priority,
        t.execution_order = s.execution_order,
        t.updated_at = CURRENT_TIMESTAMP()
WHEN NOT MATCHED THEN
    INSERT (rule_name, rule_type, tpa, source_table, target_table, rule_logic, rule_description, business_justification, priority, execution_order)
    VALUES (s.rule_name, s.rule_type, s.tpa, s.source_table, s.target_table, s.rule_logic, s.rule_description, s.business_justification, s.priority, s.execution_order);

-- Rule 3: Calculate average amounts per claim
MERGE INTO transformation_rules AS t
USING (
    SELECT
        'CALCULATE_AVG_PER_CLAIM' AS rule_name,
        'CALCULATION' AS rule_type,
        'ALL' AS tpa,
        'CLAIMS_ANALYTICS_ALL' AS source_table,
        'CLAIMS_ANALYTICS_ALL' AS target_table,
        'total_billed_amount / NULLIF(claim_count, 0), total_paid_amount / NULLIF(claim_count, 0)' AS rule_logic,
        'Calculate average billed and paid amounts per claim' AS rule_description,
        'Identify cost trends and outliers' AS business_justification,
        100 AS priority,
        3 AS execution_order
) AS s
ON t.rule_name = s.rule_name AND t.tpa = s.tpa
WHEN MATCHED THEN
    UPDATE SET
        t.rule_type = s.rule_type,
        t.source_table = s.source_table,
        t.target_table = s.target_table,
        t.rule_logic = s.rule_logic,
        t.rule_description = s.rule_description,
        t.business_justification = s.business_justification,
        t.priority = s.priority,
        t.execution_order = s.execution_order,
        t.updated_at = CURRENT_TIMESTAMP()
WHEN NOT MATCHED THEN
    INSERT (rule_name, rule_type, tpa, source_table, target_table, rule_logic, rule_description, business_justification, priority, execution_order)
    VALUES (s.rule_name, s.rule_type, s.tpa, s.source_table, s.target_table, s.rule_logic, s.rule_description, s.business_justification, s.priority, s.execution_order);

-- ============================================
-- TRANSFORMATION RULES FOR MEMBER_360
-- ============================================

-- Rule 4: Aggregate member data
MERGE INTO transformation_rules AS t
USING (
    SELECT
        'AGGREGATE_MEMBER_CLAIMS' AS rule_name,
        'AGGREGATION' AS rule_type,
        'ALL' AS tpa,
        'SILVER.CLAIMS_*' AS source_table,
        'MEMBER_360_ALL' AS target_table,
        'GROUP BY member_id, COUNT(*), SUM(paid_amount)' AS rule_logic,
        'Aggregate all claims by member' AS rule_description,
        'Create comprehensive member view for analytics' AS business_justification,
        100 AS priority,
        1 AS execution_order
) AS s
ON t.rule_name = s.rule_name AND t.tpa = s.tpa
WHEN MATCHED THEN
    UPDATE SET
        t.rule_type = s.rule_type,
        t.source_table = s.source_table,
        t.target_table = s.target_table,
        t.rule_logic = s.rule_logic,
        t.rule_description = s.rule_description,
        t.business_justification = s.business_justification,
        t.priority = s.priority,
        t.execution_order = s.execution_order,
        t.updated_at = CURRENT_TIMESTAMP()
WHEN NOT MATCHED THEN
    INSERT (rule_name, rule_type, tpa, source_table, target_table, rule_logic, rule_description, business_justification, priority, execution_order)
    VALUES (s.rule_name, s.rule_type, s.tpa, s.source_table, s.target_table, s.rule_logic, s.rule_description, s.business_justification, s.priority, s.execution_order);

-- Rule 5: Calculate member age
MERGE INTO transformation_rules AS t
USING (
    SELECT
        'CALCULATE_MEMBER_AGE' AS rule_name,
        'CALCULATION' AS rule_type,
        'ALL' AS tpa,
        'MEMBER_360_ALL' AS source_table,
        'MEMBER_360_ALL' AS target_table,
        'DATEDIFF(YEAR, date_of_birth, CURRENT_DATE())' AS rule_logic,
        'Calculate current age from date of birth' AS rule_description,
        'Enable age-based analytics and segmentation' AS business_justification,
        100 AS priority,
        2 AS execution_order
) AS s
ON t.rule_name = s.rule_name AND t.tpa = s.tpa
WHEN MATCHED THEN
    UPDATE SET
        t.rule_type = s.rule_type,
        t.source_table = s.source_table,
        t.target_table = s.target_table,
        t.rule_logic = s.rule_logic,
        t.rule_description = s.rule_description,
        t.business_justification = s.business_justification,
        t.priority = s.priority,
        t.execution_order = s.execution_order,
        t.updated_at = CURRENT_TIMESTAMP()
WHEN NOT MATCHED THEN
    INSERT (rule_name, rule_type, tpa, source_table, target_table, rule_logic, rule_description, business_justification, priority, execution_order)
    VALUES (s.rule_name, s.rule_type, s.tpa, s.source_table, s.target_table, s.rule_logic, s.rule_description, s.business_justification, s.priority, s.execution_order);

-- Rule 6: Calculate member risk score
MERGE INTO transformation_rules AS t
USING (
    SELECT
        'CALCULATE_RISK_SCORE' AS rule_name,
        'CALCULATION' AS rule_type,
        'ALL' AS tpa,
        'MEMBER_360_ALL' AS source_table,
        'MEMBER_360_ALL' AS target_table,
        'CASE WHEN total_paid > 50000 THEN 5 WHEN total_paid > 25000 THEN 4 WHEN total_paid > 10000 THEN 3 WHEN total_paid > 5000 THEN 2 ELSE 1 END' AS rule_logic,
        'Calculate member risk score based on total spend' AS rule_description,
        'Identify high-risk members for care management' AS business_justification,
        100 AS priority,
        3 AS execution_order
) AS s
ON t.rule_name = s.rule_name AND t.tpa = s.tpa
WHEN MATCHED THEN
    UPDATE SET
        t.rule_type = s.rule_type,
        t.source_table = s.source_table,
        t.target_table = s.target_table,
        t.rule_logic = s.rule_logic,
        t.rule_description = s.rule_description,
        t.business_justification = s.business_justification,
        t.priority = s.priority,
        t.execution_order = s.execution_order,
        t.updated_at = CURRENT_TIMESTAMP()
WHEN NOT MATCHED THEN
    INSERT (rule_name, rule_type, tpa, source_table, target_table, rule_logic, rule_description, business_justification, priority, execution_order)
    VALUES (s.rule_name, s.rule_type, s.tpa, s.source_table, s.target_table, s.rule_logic, s.rule_description, s.business_justification, s.priority, s.execution_order);

-- ============================================
-- TRANSFORMATION RULES FOR PROVIDER_PERFORMANCE
-- ============================================

-- Rule 7: Aggregate provider metrics
MERGE INTO transformation_rules AS t
USING (
    SELECT
        'AGGREGATE_PROVIDER_METRICS' AS rule_name,
        'AGGREGATION' AS rule_type,
        'ALL' AS tpa,
        'SILVER.CLAIMS_*' AS source_table,
        'PROVIDER_PERFORMANCE_ALL' AS target_table,
        'GROUP BY provider_id, measurement_period' AS rule_logic,
        'Aggregate provider performance metrics by period' AS rule_description,
        'Enable provider network optimization' AS business_justification,
        100 AS priority,
        1 AS execution_order
) AS s
ON t.rule_name = s.rule_name AND t.tpa = s.tpa
WHEN MATCHED THEN
    UPDATE SET
        t.rule_type = s.rule_type,
        t.source_table = s.source_table,
        t.target_table = s.target_table,
        t.rule_logic = s.rule_logic,
        t.rule_description = s.rule_description,
        t.business_justification = s.business_justification,
        t.priority = s.priority,
        t.execution_order = s.execution_order,
        t.updated_at = CURRENT_TIMESTAMP()
WHEN NOT MATCHED THEN
    INSERT (rule_name, rule_type, tpa, source_table, target_table, rule_logic, rule_description, business_justification, priority, execution_order)
    VALUES (s.rule_name, s.rule_type, s.tpa, s.source_table, s.target_table, s.rule_logic, s.rule_description, s.business_justification, s.priority, s.execution_order);

-- Rule 8: Calculate provider efficiency metrics
MERGE INTO transformation_rules AS t
USING (
    SELECT
        'CALCULATE_PROVIDER_EFFICIENCY' AS rule_name,
        'CALCULATION' AS rule_type,
        'ALL' AS tpa,
        'PROVIDER_PERFORMANCE_ALL' AS source_table,
        'PROVIDER_PERFORMANCE_ALL' AS target_table,
        'total_paid / NULLIF(unique_members, 0), total_paid / NULLIF(total_claims, 0)' AS rule_logic,
        'Calculate cost per member and cost per claim' AS rule_description,
        'Identify efficient providers for network optimization' AS business_justification,
        100 AS priority,
        2 AS execution_order
) AS s
ON t.rule_name = s.rule_name AND t.tpa = s.tpa
WHEN MATCHED THEN
    UPDATE SET
        t.rule_type = s.rule_type,
        t.source_table = s.source_table,
        t.target_table = s.target_table,
        t.rule_logic = s.rule_logic,
        t.rule_description = s.rule_description,
        t.business_justification = s.business_justification,
        t.priority = s.priority,
        t.execution_order = s.execution_order,
        t.updated_at = CURRENT_TIMESTAMP()
WHEN NOT MATCHED THEN
    INSERT (rule_name, rule_type, tpa, source_table, target_table, rule_logic, rule_description, business_justification, priority, execution_order)
    VALUES (s.rule_name, s.rule_type, s.tpa, s.source_table, s.target_table, s.rule_logic, s.rule_description, s.business_justification, s.priority, s.execution_order);

-- ============================================
-- TRANSFORMATION RULES FOR FINANCIAL_SUMMARY
-- ============================================

-- Rule 9: Aggregate financial metrics
MERGE INTO transformation_rules AS t
USING (
    SELECT
        'AGGREGATE_FINANCIAL_METRICS' AS rule_name,
        'AGGREGATION' AS rule_type,
        'ALL' AS tpa,
        'SILVER.CLAIMS_*' AS source_table,
        'FINANCIAL_SUMMARY_ALL' AS target_table,
        'GROUP BY fiscal_year, fiscal_month, claim_type' AS rule_logic,
        'Aggregate financial metrics by period and type' AS rule_description,
        'Enable financial reporting and forecasting' AS business_justification,
        100 AS priority,
        1 AS execution_order
) AS s
ON t.rule_name = s.rule_name AND t.tpa = s.tpa
WHEN MATCHED THEN
    UPDATE SET
        t.rule_type = s.rule_type,
        t.source_table = s.source_table,
        t.target_table = s.target_table,
        t.rule_logic = s.rule_logic,
        t.rule_description = s.rule_description,
        t.business_justification = s.business_justification,
        t.priority = s.priority,
        t.execution_order = s.execution_order,
        t.updated_at = CURRENT_TIMESTAMP()
WHEN NOT MATCHED THEN
    INSERT (rule_name, rule_type, tpa, source_table, target_table, rule_logic, rule_description, business_justification, priority, execution_order)
    VALUES (s.rule_name, s.rule_type, s.tpa, s.source_table, s.target_table, s.rule_logic, s.rule_description, s.business_justification, s.priority, s.execution_order);

-- Rule 10: Calculate PMPM
MERGE INTO transformation_rules AS t
USING (
    SELECT
        'CALCULATE_PMPM' AS rule_name,
        'CALCULATION' AS rule_type,
        'ALL' AS tpa,
        'FINANCIAL_SUMMARY_ALL' AS source_table,
        'FINANCIAL_SUMMARY_ALL' AS target_table,
        'total_paid / NULLIF(member_count, 0)' AS rule_logic,
        'Calculate Per Member Per Month cost' AS rule_description,
        'Key metric for financial performance tracking' AS business_justification,
        100 AS priority,
        2 AS execution_order
) AS s
ON t.rule_name = s.rule_name AND t.tpa = s.tpa
WHEN MATCHED THEN
    UPDATE SET
        t.rule_type = s.rule_type,
        t.source_table = s.source_table,
        t.target_table = s.target_table,
        t.rule_logic = s.rule_logic,
        t.rule_description = s.rule_description,
        t.business_justification = s.business_justification,
        t.priority = s.priority,
        t.execution_order = s.execution_order,
        t.updated_at = CURRENT_TIMESTAMP()
WHEN NOT MATCHED THEN
    INSERT (rule_name, rule_type, tpa, source_table, target_table, rule_logic, rule_description, business_justification, priority, execution_order)
    VALUES (s.rule_name, s.rule_type, s.tpa, s.source_table, s.target_table, s.rule_logic, s.rule_description, s.business_justification, s.priority, s.execution_order);

-- Rule 11: Calculate Medical Loss Ratio
MERGE INTO transformation_rules AS t
USING (
    SELECT
        'CALCULATE_MLR' AS rule_name,
        'CALCULATION' AS rule_type,
        'ALL' AS tpa,
        'FINANCIAL_SUMMARY_ALL' AS source_table,
        'FINANCIAL_SUMMARY_ALL' AS target_table,
        'total_paid / NULLIF(total_billed, 0)' AS rule_logic,
        'Calculate Medical Loss Ratio' AS rule_description,
        'Regulatory requirement and key financial metric' AS business_justification,
        100 AS priority,
        3 AS execution_order
) AS s
ON t.rule_name = s.rule_name AND t.tpa = s.tpa
WHEN MATCHED THEN
    UPDATE SET
        t.rule_type = s.rule_type,
        t.source_table = s.source_table,
        t.target_table = s.target_table,
        t.rule_logic = s.rule_logic,
        t.rule_description = s.rule_description,
        t.business_justification = s.business_justification,
        t.priority = s.priority,
        t.execution_order = s.execution_order,
        t.updated_at = CURRENT_TIMESTAMP()
WHEN NOT MATCHED THEN
    INSERT (rule_name, rule_type, tpa, source_table, target_table, rule_logic, rule_description, business_justification, priority, execution_order)
    VALUES (s.rule_name, s.rule_type, s.tpa, s.source_table, s.target_table, s.rule_logic, s.rule_description, s.business_justification, s.priority, s.execution_order);

-- ============================================
-- QUALITY RULES
-- ============================================

-- Quality Rule 1: Check for negative amounts
MERGE INTO quality_rules AS t
USING (
    SELECT
        'CHECK_NEGATIVE_AMOUNTS' AS rule_name,
        'VALIDITY' AS rule_type,
        'CLAIMS_ANALYTICS_ALL' AS table_name,
        'ALL' AS tpa,
        'total_paid_amount' AS field_name,
        'total_paid_amount >= 0' AS check_logic,
        0 AS threshold_value,
        '>=' AS threshold_operator,
        'ERROR' AS severity,
        'REJECT' AS action_on_failure
) AS s
ON t.rule_name = s.rule_name AND t.tpa = s.tpa
WHEN MATCHED THEN
    UPDATE SET
        t.rule_type = s.rule_type,
        t.table_name = s.table_name,
        t.field_name = s.field_name,
        t.check_logic = s.check_logic,
        t.threshold_value = s.threshold_value,
        t.threshold_operator = s.threshold_operator,
        t.severity = s.severity,
        t.action_on_failure = s.action_on_failure,
        t.updated_at = CURRENT_TIMESTAMP()
WHEN NOT MATCHED THEN
    INSERT (rule_name, rule_type, table_name, tpa, field_name, check_logic, threshold_value, threshold_operator, severity, action_on_failure)
    VALUES (s.rule_name, s.rule_type, s.table_name, s.tpa, s.field_name, s.check_logic, s.threshold_value, s.threshold_operator, s.severity, s.action_on_failure);

-- Quality Rule 2: Check completeness of key fields
MERGE INTO quality_rules AS t
USING (
    SELECT
        'CHECK_REQUIRED_FIELDS' AS rule_name,
        'COMPLETENESS' AS rule_type,
        'CLAIMS_ANALYTICS_ALL' AS table_name,
        'ALL' AS tpa,
        NULL AS field_name,
        'claim_year IS NOT NULL AND claim_month IS NOT NULL AND claim_type IS NOT NULL' AS check_logic,
        100 AS threshold_value,
        '=' AS threshold_operator,
        'CRITICAL' AS severity,
        'REJECT' AS action_on_failure
) AS s
ON t.rule_name = s.rule_name AND t.tpa = s.tpa
WHEN MATCHED THEN
    UPDATE SET
        t.rule_type = s.rule_type,
        t.table_name = s.table_name,
        t.field_name = s.field_name,
        t.check_logic = s.check_logic,
        t.threshold_value = s.threshold_value,
        t.threshold_operator = s.threshold_operator,
        t.severity = s.severity,
        t.action_on_failure = s.action_on_failure,
        t.updated_at = CURRENT_TIMESTAMP()
WHEN NOT MATCHED THEN
    INSERT (rule_name, rule_type, table_name, tpa, field_name, check_logic, threshold_value, threshold_operator, severity, action_on_failure)
    VALUES (s.rule_name, s.rule_type, s.table_name, s.tpa, s.field_name, s.check_logic, s.threshold_value, s.threshold_operator, s.severity, s.action_on_failure);

-- Quality Rule 3: Check discount rate reasonableness
MERGE INTO quality_rules AS t
USING (
    SELECT
        'CHECK_DISCOUNT_RATE' AS rule_name,
        'VALIDITY' AS rule_type,
        'CLAIMS_ANALYTICS_ALL' AS table_name,
        'ALL' AS tpa,
        'discount_rate' AS field_name,
        'discount_rate BETWEEN 0 AND 1' AS check_logic,
        1 AS threshold_value,
        '<=' AS threshold_operator,
        'WARNING' AS severity,
        'FLAG' AS action_on_failure
) AS s
ON t.rule_name = s.rule_name AND t.tpa = s.tpa
WHEN MATCHED THEN
    UPDATE SET
        t.rule_type = s.rule_type,
        t.table_name = s.table_name,
        t.field_name = s.field_name,
        t.check_logic = s.check_logic,
        t.threshold_value = s.threshold_value,
        t.threshold_operator = s.threshold_operator,
        t.severity = s.severity,
        t.action_on_failure = s.action_on_failure,
        t.updated_at = CURRENT_TIMESTAMP()
WHEN NOT MATCHED THEN
    INSERT (rule_name, rule_type, table_name, tpa, field_name, check_logic, threshold_value, threshold_operator, severity, action_on_failure)
    VALUES (s.rule_name, s.rule_type, s.table_name, s.tpa, s.field_name, s.check_logic, s.threshold_value, s.threshold_operator, s.severity, s.action_on_failure);

-- Quality Rule 4: Check member count consistency
MERGE INTO quality_rules AS t
USING (
    SELECT
        'CHECK_MEMBER_COUNT' AS rule_name,
        'CONSISTENCY' AS rule_type,
        'MEMBER_360_ALL' AS table_name,
        'ALL' AS tpa,
        'total_claims' AS field_name,
        'total_claims = medical_claims + dental_claims + pharmacy_claims' AS check_logic,
        100 AS threshold_value,
        '=' AS threshold_operator,
        'ERROR' AS severity,
        'FLAG' AS action_on_failure
) AS s
ON t.rule_name = s.rule_name AND t.tpa = s.tpa
WHEN MATCHED THEN
    UPDATE SET
        t.rule_type = s.rule_type,
        t.table_name = s.table_name,
        t.field_name = s.field_name,
        t.check_logic = s.check_logic,
        t.threshold_value = s.threshold_value,
        t.threshold_operator = s.threshold_operator,
        t.severity = s.severity,
        t.action_on_failure = s.action_on_failure,
        t.updated_at = CURRENT_TIMESTAMP()
WHEN NOT MATCHED THEN
    INSERT (rule_name, rule_type, table_name, tpa, field_name, check_logic, threshold_value, threshold_operator, severity, action_on_failure)
    VALUES (s.rule_name, s.rule_type, s.table_name, s.tpa, s.field_name, s.check_logic, s.threshold_value, s.threshold_operator, s.severity, s.action_on_failure);

-- Quality Rule 5: Check data freshness
MERGE INTO quality_rules AS t
USING (
    SELECT
        'CHECK_DATA_FRESHNESS' AS rule_name,
        'TIMELINESS' AS rule_type,
        'CLAIMS_ANALYTICS_ALL' AS table_name,
        'ALL' AS tpa,
        'DATEDIFF(DAY, MAX(updated_at), CURRENT_TIMESTAMP()) <= 1' AS check_logic,
        1 AS threshold_value,
        '<=' AS threshold_operator,
        'WARNING' AS severity,
        'ALERT' AS action_on_failure
) AS s
ON t.rule_name = s.rule_name AND t.tpa = s.tpa
WHEN MATCHED THEN
    UPDATE SET
        t.rule_type = s.rule_type,
        t.table_name = s.table_name,
        t.check_logic = s.check_logic,
        t.threshold_value = s.threshold_value,
        t.threshold_operator = s.threshold_operator,
        t.severity = s.severity,
        t.action_on_failure = s.action_on_failure,
        t.updated_at = CURRENT_TIMESTAMP()
WHEN NOT MATCHED THEN
    INSERT (rule_name, rule_type, table_name, tpa, check_logic, threshold_value, threshold_operator, severity, action_on_failure)
    VALUES (s.rule_name, s.rule_type, s.table_name, s.tpa, s.check_logic, s.threshold_value, s.threshold_operator, s.severity, s.action_on_failure);

-- ============================================
-- BUSINESS METRICS
-- ============================================

-- Metric 1: Total Healthcare Spend
MERGE INTO business_metrics AS t
USING (
    SELECT
        'TOTAL_HEALTHCARE_SPEND' AS metric_name,
        'FINANCIAL' AS metric_category,
        'ALL' AS tpa,
        'SUM(total_paid) FROM FINANCIAL_SUMMARY_ALL' AS calculation_logic,
        'FINANCIAL_SUMMARY_ALL' AS source_tables,
        'DAILY' AS refresh_frequency,
        'CFO' AS metric_owner,
        'Total healthcare spend across all claim types' AS description
) AS s
ON t.metric_name = s.metric_name AND t.tpa = s.tpa
WHEN MATCHED THEN
    UPDATE SET
        t.metric_category = s.metric_category,
        t.calculation_logic = s.calculation_logic,
        t.source_tables = s.source_tables,
        t.refresh_frequency = s.refresh_frequency,
        t.metric_owner = s.metric_owner,
        t.description = s.description,
        t.updated_at = CURRENT_TIMESTAMP()
WHEN NOT MATCHED THEN
    INSERT (metric_name, metric_category, tpa, calculation_logic, source_tables, refresh_frequency, metric_owner, description)
    VALUES (s.metric_name, s.metric_category, s.tpa, s.calculation_logic, s.source_tables, s.refresh_frequency, s.metric_owner, s.description);

-- Metric 2: Average Cost Per Member
MERGE INTO business_metrics AS t
USING (
    SELECT
        'AVG_COST_PER_MEMBER' AS metric_name,
        'FINANCIAL' AS metric_category,
        'ALL' AS tpa,
        'SUM(total_paid) / COUNT(DISTINCT member_id) FROM MEMBER_360_ALL' AS calculation_logic,
        'MEMBER_360_ALL' AS source_tables,
        'DAILY' AS refresh_frequency,
        'CFO' AS metric_owner,
        'Average healthcare cost per member' AS description
) AS s
ON t.metric_name = s.metric_name AND t.tpa = s.tpa
WHEN MATCHED THEN
    UPDATE SET
        t.metric_category = s.metric_category,
        t.calculation_logic = s.calculation_logic,
        t.source_tables = s.source_tables,
        t.refresh_frequency = s.refresh_frequency,
        t.metric_owner = s.metric_owner,
        t.description = s.description,
        t.updated_at = CURRENT_TIMESTAMP()
WHEN NOT MATCHED THEN
    INSERT (metric_name, metric_category, tpa, calculation_logic, source_tables, refresh_frequency, metric_owner, description)
    VALUES (s.metric_name, s.metric_category, s.tpa, s.calculation_logic, s.source_tables, s.refresh_frequency, s.metric_owner, s.description);

-- Metric 3: Member Engagement Rate
MERGE INTO business_metrics AS t
USING (
    SELECT
        'MEMBER_ENGAGEMENT_RATE' AS metric_name,
        'OPERATIONAL' AS metric_category,
        'ALL' AS tpa,
        'COUNT(DISTINCT CASE WHEN total_claims > 0 THEN member_id END) / COUNT(DISTINCT member_id) FROM MEMBER_360_ALL' AS calculation_logic,
        'MEMBER_360_ALL' AS source_tables,
        'WEEKLY' AS refresh_frequency,
        'COO' AS metric_owner,
        'Percentage of members with at least one claim' AS description
) AS s
ON t.metric_name = s.metric_name AND t.tpa = s.tpa
WHEN MATCHED THEN
    UPDATE SET
        t.metric_category = s.metric_category,
        t.calculation_logic = s.calculation_logic,
        t.source_tables = s.source_tables,
        t.refresh_frequency = s.refresh_frequency,
        t.metric_owner = s.metric_owner,
        t.description = s.description,
        t.updated_at = CURRENT_TIMESTAMP()
WHEN NOT MATCHED THEN
    INSERT (metric_name, metric_category, tpa, calculation_logic, source_tables, refresh_frequency, metric_owner, description)
    VALUES (s.metric_name, s.metric_category, s.tpa, s.calculation_logic, s.source_tables, s.refresh_frequency, s.metric_owner, s.description);

-- Metric 4: Provider Network Efficiency
MERGE INTO business_metrics AS t
USING (
    SELECT
        'PROVIDER_NETWORK_EFFICIENCY' AS metric_name,
        'OPERATIONAL' AS metric_category,
        'ALL' AS tpa,
        'AVG(discount_rate) FROM PROVIDER_PERFORMANCE_ALL' AS calculation_logic,
        'PROVIDER_PERFORMANCE_ALL' AS source_tables,
        'WEEKLY' AS refresh_frequency,
        'Network Director' AS metric_owner,
        'Average discount rate across provider network' AS description
) AS s
ON t.metric_name = s.metric_name AND t.tpa = s.tpa
WHEN MATCHED THEN
    UPDATE SET
        t.metric_category = s.metric_category,
        t.calculation_logic = s.calculation_logic,
        t.source_tables = s.source_tables,
        t.refresh_frequency = s.refresh_frequency,
        t.metric_owner = s.metric_owner,
        t.description = s.description,
        t.updated_at = CURRENT_TIMESTAMP()
WHEN NOT MATCHED THEN
    INSERT (metric_name, metric_category, tpa, calculation_logic, source_tables, refresh_frequency, metric_owner, description)
    VALUES (s.metric_name, s.metric_category, s.tpa, s.calculation_logic, s.source_tables, s.refresh_frequency, s.metric_owner, s.description);

-- Metric 5: High Risk Member Count
MERGE INTO business_metrics AS t
USING (
    SELECT
        'HIGH_RISK_MEMBER_COUNT' AS metric_name,
        'CLINICAL' AS metric_category,
        'ALL' AS tpa,
        'COUNT(*) FROM MEMBER_360_ALL WHERE risk_score >= 4' AS calculation_logic,
        'MEMBER_360_ALL' AS source_tables,
        'DAILY' AS refresh_frequency,
        'Chief Medical Officer' AS metric_owner,
        'Count of members with high risk scores (4-5)' AS description
) AS s
ON t.metric_name = s.metric_name AND t.tpa = s.tpa
WHEN MATCHED THEN
    UPDATE SET
        t.metric_category = s.metric_category,
        t.calculation_logic = s.calculation_logic,
        t.source_tables = s.source_tables,
        t.refresh_frequency = s.refresh_frequency,
        t.metric_owner = s.metric_owner,
        t.description = s.description,
        t.updated_at = CURRENT_TIMESTAMP()
WHEN NOT MATCHED THEN
    INSERT (metric_name, metric_category, tpa, calculation_logic, source_tables, refresh_frequency, metric_owner, description)
    VALUES (s.metric_name, s.metric_category, s.tpa, s.calculation_logic, s.source_tables, s.refresh_frequency, s.metric_owner, s.description);

-- ============================================
-- COMPLETION MESSAGE
-- ============================================

SELECT 'Gold Transformation Rules Created' AS status,
       COUNT(*) AS rule_count
FROM transformation_rules;

SELECT 'Gold Quality Rules Created' AS status,
       COUNT(*) AS rule_count
FROM quality_rules;

SELECT 'Gold Business Metrics Created' AS status,
       COUNT(*) AS metric_count
FROM business_metrics;
