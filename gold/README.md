# Gold Layer

**Analytics-ready aggregated data**

---

## Overview

The Gold layer handles:
- Claims analytics aggregations
- Member 360 views
- Member journey tracking
- MERGE-based transformations
- Optimized for reporting and BI

---

## Quick Start

### Deploy Gold Layer

```bash
cd deployment
./deploy_gold.sh
```

### View Analytics

```sql
USE DATABASE BORDEREAU_PROCESSING_PIPELINE;

-- Claims analytics
SELECT * FROM GOLD.CLAIMS_ANALYTICS LIMIT 100;

-- Member 360
SELECT * FROM GOLD.MEMBER_360 LIMIT 100;

-- Member journeys
SELECT * FROM GOLD.MEMBER_JOURNEYS LIMIT 100;
```

---

## Key Tables

| Table | Purpose | Grain |
|-------|---------|-------|
| `CLAIMS_ANALYTICS` | Claims aggregations | TPA, Year, Month, Type, Provider |
| `MEMBER_360` | Member summary | TPA, Member ID |
| `MEMBER_JOURNEYS` | Member timeline | TPA, Member ID, Sequence |

---

## SQL Files

| File | Purpose |
|------|---------|
| `1_Gold_Schema_Setup.sql` | Create Gold schema |
| `2_Gold_Target_Schemas.sql` | Create target tables |
| `3_Gold_Transformation_Rules.sql` | Transformation rules |
| `4_Gold_Transformation_Procedures.sql` | MERGE-based transformations |
| `5_Gold_Tasks.sql` | Automated transformation tasks |
| `6_Member_Journeys.sql` | Member journey logic |

---

## Transformations

### Claims Analytics

Aggregates claims by:
- TPA
- Year and Month
- Claim Type
- Provider ID

**Metrics:**
- Total claims
- Total billed amount
- Total paid amount
- Average claim amount

### Member 360

Summarizes per member:
- Total claims
- Total billed/paid amounts
- First/last claim dates
- Unique providers
- Unique claim types

### Member Journeys

Tracks member timeline:
- Chronological claim sequence
- Days between claims
- Cumulative totals
- Journey stage

---

## Bulk Load Optimization (v3.1)

**88% faster** than original implementation:
- Batch processing with 50K records per batch
- Parallel execution
- Optimized MERGE statements
- Reduced warehouse usage

See `2_Gold_Target_Schemas_OPTIMIZED.sql` for details.

---

## Documentation

**Quick Reference**: [docs/QUICK_REFERENCE.md](../docs/QUICK_REFERENCE.md)  
**Architecture**: [docs/ARCHITECTURE.md](../docs/ARCHITECTURE.md)  
**User Guide**: [docs/USER_GUIDE.md](../docs/USER_GUIDE.md)

---

**Version**: 3.1 | **Status**: ✅ Production Ready
