# Changelog

All notable changes to the Bordereau Processing Pipeline.

## [Unreleased]

### Known Issues
- JSON escaping in Snowflake logger causing PARSE_JSON errors
- Logging system needs escaping fixes for full functionality

---

## [2026-01-31] - Validation, Logging, and Data Quality

### Added - Transformation Validation System
- **Mapping validation** at creation: Prevents duplicates and validates column existence
- **Manual validation endpoint**: `GET /api/silver/mappings/validate` with detailed reports
- **Pre-transformation validation**: Auto-validates before running transformations
- **Clear error messages**: Actionable feedback for mapping issues

**Impact**: Eliminates silent failures, prevents wasted compute, improves UX

**Files**: `backend/app/api/silver.py`  
**Details**: [TRANSFORMATION_VALIDATION_FIX.md](changelog/TRANSFORMATION_VALIDATION_FIX.md)

### Added - Logging System
- **Snowflake logging**: Custom handler writing to hybrid tables
- **API middleware**: Captures all HTTP requests/responses with timing
- **Error tracking**: Stack traces and context in ERROR_LOGS table
- **Async logging**: Non-blocking with batching

**Tables**: `APPLICATION_LOGS`, `API_REQUEST_LOGS`, `ERROR_LOGS`  
**Files**: `backend/app/utils/snowflake_logger.py`, `backend/app/middleware/logging_middleware.py`  
**Details**: [LOGGING_SYSTEM_IMPLEMENTATION.md](changelog/LOGGING_SYSTEM_IMPLEMENTATION.md)

### Added - MERGE Transformations
- **Idempotent transformations**: MERGE instead of INSERT prevents duplicates
- **7 metadata columns**: `_RECORD_ID`, `_FILE_NAME`, `_FILE_ROW_NUMBER`, `_TPA`, `_BATCH_ID`, `_LOAD_TIMESTAMP`, `_LOADED_BY`
- **Source traceability**: Complete lineage from Bronze to Silver
- **Audit trail**: Tracks who processed data and when

**Files**: `silver/2_Silver_Target_Schemas.sql`, `silver/5_Silver_Transformation_Logic.sql`  
**Details**: [MERGE_TRANSFORMATION_UPDATE.md](changelog/MERGE_TRANSFORMATION_UPDATE.md)

### Fixed - Schema Update Crashes
- **500 errors**: Fixed null handling in schema column updates
- **Frontend**: Only sends changed fields, filters null values
- **Backend**: Request body parsing to distinguish "not provided" vs "null"

**Files**: `frontend/src/pages/SilverSchemas.tsx`, `backend/app/api/silver.py`  
**Details**: [SCHEMA_UPDATE_500_ERROR_FIX.md](changelog/SCHEMA_UPDATE_500_ERROR_FIX.md)

---

## [2026-01] - Core Platform

### Features
- **Bronze Layer**: File ingestion, raw storage, TPA management
- **Silver Layer**: Transformations, field mappings, target schemas, ML/LLM auto-mapping
- **Gold Layer**: Analytics tables, aggregations, member journeys
- **UI**: React + TypeScript with Ant Design components
- **API**: FastAPI with OAuth and caller's rights
- **Deployment**: Snowpark Container Services with automated scripts
- **Infrastructure**: Docker containers, task-based pipeline, sample data

### Documentation
- Consolidated architecture and system design docs
- Created user guides and deployment guides
- Component READMEs for each layer

---

## Documentation

**Active Docs**:
- [README](../README.md) - Overview
- [QUICK_START](../QUICK_START.md) - Fast setup
- [ARCHITECTURE](ARCHITECTURE.md) - System design (includes recent enhancements)
- [USER_GUIDE](USER_GUIDE.md) - Usage guide

**Archived Details**: See `docs/changelog/` for detailed fix documentation

**Format**: Follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) - Added/Changed/Fixed/Removed
