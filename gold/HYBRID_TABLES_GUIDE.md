# Hybrid Tables vs Standard Tables in Gold Layer

## Overview

The Gold layer uses a mix of **Hybrid Tables** and **Standard Tables** to optimize performance based on access patterns.

## Table Types

### Hybrid Tables (Metadata Tables)

Hybrid tables support row-level operations and indexes, making them ideal for:
- Frequent point queries (lookups by ID or key)
- Small to medium-sized metadata tables
- Tables with many UPDATE operations
- Tables requiring indexes for performance

**Gold Layer Hybrid Tables:**
1. `target_schemas` - Fast schema lookups
2. `target_fields` - Fast field definition lookups
3. `transformation_rules` - Fast rule lookups during transformations
4. `field_mappings` - Fast mapping lookups
5. `quality_rules` - Fast quality rule lookups
6. `business_metrics` - Fast metric definition lookups

**Indexes on Hybrid Tables:**
```sql
-- Example: transformation_rules
CREATE HYBRID TABLE transformation_rules (
    rule_id NUMBER(38,0) AUTOINCREMENT PRIMARY KEY,
    rule_name VARCHAR(500) NOT NULL,
    rule_type VARCHAR(100) NOT NULL,
    tpa VARCHAR(100) NOT NULL,
    ...
    INDEX idx_trans_rules_tpa (tpa),
    INDEX idx_trans_rules_type (rule_type),
    INDEX idx_trans_rules_active (is_active)
);
```

### Standard Tables (Analytics & Log Tables)

Standard tables are optimized for analytical queries and use clustering keys:
- Large fact tables with millions of rows
- Append-heavy tables (logs, history)
- Tables primarily queried with scans
- Time-series data

**Gold Layer Standard Tables:**
1. `processing_log` - Append-only processing history
2. `quality_check_results` - Append-only quality results
3. `CLAIMS_ANALYTICS_ALL` - Large analytics table with clustering
4. `MEMBER_360_ALL` - Large member data with clustering
5. `PROVIDER_PERFORMANCE_ALL` - Provider metrics with clustering
6. `FINANCIAL_SUMMARY_ALL` - Financial data with clustering

**Clustering Keys on Standard Tables:**
```sql
-- Example: CLAIMS_ANALYTICS_ALL
CREATE TABLE CLAIMS_ANALYTICS_ALL (
    ...
) CLUSTER BY (tpa, claim_year, claim_month, claim_type);

-- Example: MEMBER_360_ALL
CREATE TABLE MEMBER_360_ALL (
    ...
) CLUSTER BY (tpa, member_id);
```

## Performance Optimization

### When to Use Hybrid Tables

✅ **Use Hybrid Tables when:**
- Table size < 10 million rows
- Frequent point queries (WHERE id = X)
- Many UPDATE/DELETE operations
- Need for indexes
- Metadata or configuration tables

❌ **Don't Use Hybrid Tables when:**
- Table size > 10 million rows
- Primarily analytical queries (scans, aggregations)
- Append-only workload
- Time-series data

### When to Use Standard Tables with Clustering

✅ **Use Standard Tables when:**
- Large fact tables (> 10 million rows)
- Analytical queries (GROUP BY, aggregations)
- Time-series data
- Append-heavy workload
- Data warehouse patterns

**Clustering Keys:**
- Choose columns used in WHERE and JOIN clauses
- Typically: date columns, ID columns, frequently filtered columns
- Maximum 4 columns recommended
- Order matters: most selective first

## Examples

### Hybrid Table with Indexes

```sql
-- Fast lookups by tpa and rule_type
CREATE HYBRID TABLE transformation_rules (
    rule_id NUMBER(38,0) PRIMARY KEY,
    rule_name VARCHAR(500) NOT NULL,
    rule_type VARCHAR(100) NOT NULL,
    tpa VARCHAR(100) NOT NULL,
    rule_logic VARCHAR(4000),
    is_active BOOLEAN DEFAULT TRUE,
    INDEX idx_tpa (tpa),
    INDEX idx_type (rule_type),
    INDEX idx_active (is_active)
);

-- Fast query with index
SELECT * FROM transformation_rules 
WHERE tpa = 'PROVIDER_A' AND is_active = TRUE;
```

### Standard Table with Clustering

```sql
-- Optimized for time-series analytics
CREATE TABLE CLAIMS_ANALYTICS_ALL (
    claim_analytics_id NUMBER(38,0),
    tpa VARCHAR(100),
    claim_year NUMBER(4,0),
    claim_month NUMBER(2,0),
    claim_type VARCHAR(50),
    total_paid_amount NUMBER(18,2),
    ...
) CLUSTER BY (tpa, claim_year, claim_month, claim_type);

-- Efficient query using clustering keys
SELECT 
    claim_year,
    claim_month,
    SUM(total_paid_amount)
FROM CLAIMS_ANALYTICS_ALL
WHERE tpa = 'PROVIDER_A'
  AND claim_year = 2024
  AND claim_month BETWEEN 1 AND 6
GROUP BY claim_year, claim_month;
```

## Silver Layer Table Types

### Hybrid Tables (Metadata)
- `target_schemas` - Schema definitions
- `field_mappings` - Field mappings
- `transformation_rules` - Transformation rules
- `llm_prompt_templates` - LLM templates

### Standard Tables (Data & Logs)
- `silver_processing_log` - Processing history
- `data_quality_metrics` - Quality metrics
- `quarantine_records` - Quarantined data
- `processing_watermarks` - Watermark tracking
- `CLAIMS_*` - Actual claims tables (with clustering)

## Gold Layer Table Types

### Hybrid Tables (Metadata)
- `target_schemas` - 6 indexes
- `target_fields` - 1 index
- `transformation_rules` - 3 indexes
- `field_mappings` - 3 indexes
- `quality_rules` - 3 indexes
- `business_metrics` - 2 indexes

**Total**: 6 hybrid tables, 18 indexes

### Standard Tables (Analytics & Logs)
- `processing_log` - Append-only logs
- `quality_check_results` - Append-only results
- `CLAIMS_ANALYTICS_ALL` - Clustered by (tpa, year, month, type)
- `MEMBER_360_ALL` - Clustered by (tpa, member_id)
- `PROVIDER_PERFORMANCE_ALL` - Clustered by (tpa, provider_id, period)
- `FINANCIAL_SUMMARY_ALL` - Clustered by (tpa, year, month)

**Total**: 6 standard tables with clustering keys

## Performance Comparison

### Hybrid Table Performance

```sql
-- Point query: ~10ms
SELECT * FROM transformation_rules 
WHERE rule_id = 123;  -- Uses PRIMARY KEY index

-- Filtered query: ~50ms
SELECT * FROM transformation_rules 
WHERE tpa = 'PROVIDER_A' AND is_active = TRUE;  -- Uses indexes
```

### Standard Table Performance

```sql
-- Analytical query: ~500ms (with clustering)
SELECT 
    claim_year,
    SUM(total_paid_amount)
FROM CLAIMS_ANALYTICS_ALL
WHERE tpa = 'PROVIDER_A'  -- Uses clustering
  AND claim_year = 2024
GROUP BY claim_year;

-- Without clustering: ~2000ms
-- Clustering provides 4x performance improvement
```

## Best Practices

### 1. Choose the Right Table Type

- **Metadata** → Hybrid Tables
- **Analytics** → Standard Tables with Clustering
- **Logs** → Standard Tables (no clustering needed)

### 2. Index Strategy for Hybrid Tables

- Index columns used in WHERE clauses
- Index foreign keys
- Index frequently joined columns
- Maximum 5-10 indexes per table

### 3. Clustering Strategy for Standard Tables

- Cluster on columns used in WHERE and JOIN
- Use 2-4 columns maximum
- Order by selectivity (most selective first)
- Monitor clustering depth

### 4. Monitoring

```sql
-- Check hybrid table size
SELECT 
    table_name,
    row_count,
    bytes / (1024*1024*1024) AS size_gb
FROM INFORMATION_SCHEMA.TABLES
WHERE table_type = 'HYBRID'
  AND table_schema = 'GOLD';

-- Check clustering quality
SELECT 
    table_name,
    clustering_key,
    average_depth,
    average_overlaps
FROM TABLE(INFORMATION_SCHEMA.AUTOMATIC_CLUSTERING_HISTORY())
WHERE table_schema = 'GOLD'
ORDER BY end_time DESC;
```

## Migration Considerations

### From Standard to Hybrid

If a metadata table grows beyond 10M rows, consider:
1. Partitioning the data
2. Archiving old records
3. Keeping as standard table with better clustering

### From Hybrid to Standard

If query patterns change to analytical:
1. Create new standard table with clustering
2. Copy data
3. Drop hybrid table
4. Update procedures

## Summary

| Table Type | Use Case | Size Limit | Performance Feature |
|------------|----------|------------|---------------------|
| **Hybrid** | Metadata, lookups | < 10M rows | Indexes (PRIMARY KEY, INDEX) |
| **Standard** | Analytics, logs | Unlimited | Clustering keys (CLUSTER BY) |

**Gold Layer:**
- 6 Hybrid Tables (metadata) with 18 indexes
- 6 Standard Tables (analytics/logs) with clustering keys

**Result**: Optimized performance for both transactional and analytical workloads!

---

**Last Updated**: January 19, 2026  
**Version**: 1.0
