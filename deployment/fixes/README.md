# Deployment Fixes Documentation

This directory contains detailed documentation for various fixes and troubleshooting solutions implemented in the deployment process.

---

## Fix Categories

### Container Deployment Fixes

| Document | Description | Date |
|----------|-------------|------|
| [CONTAINER_DEPLOYMENT_FIX.md](CONTAINER_DEPLOYMENT_FIX.md) | Drop and recreate strategy for SPCS services | Jan 19, 2026 |
| [TROUBLESHOOT_SERVICE_CREATION.md](TROUBLESHOOT_SERVICE_CREATION.md) | Troubleshooting service creation failures | Jan 19, 2026 |
| [TROUBLESHOOTING_500_ERRORS.md](TROUBLESHOOTING_500_ERRORS.md) | Resolving 500 errors in SPCS | Jan 19, 2026 |
| [REDEPLOY_WAREHOUSE_FIX.md](REDEPLOY_WAREHOUSE_FIX.md) | Warehouse configuration for redeployment | Jan 19, 2026 |
| [WAREHOUSE_FIX.md](WAREHOUSE_FIX.md) | Warehouse fix for SPCS OAuth | Jan 19, 2026 |
| [AUTHENTICATION_POLICY_FIX.md](AUTHENTICATION_POLICY_FIX.md) | Remove unsupported authenticationPolicy option | Jan 21, 2026 |
| [READINESS_PROBE_FIX.md](READINESS_PROBE_FIX.md) | Backend readiness probe failure in SPCS | Jan 21, 2026 |
| [DOCKERIGNORE_FRONTEND_FIX.md](DOCKERIGNORE_FRONTEND_FIX.md) | .dockerignore excluding frontend source code | Jan 21, 2026 |
| [SERVICE_ALREADY_EXISTS_FIX.md](SERVICE_ALREADY_EXISTS_FIX.md) | Service already exists error during deployment | Jan 21, 2026 |
| [ENDPOINT_CHECK_FIX.md](ENDPOINT_CHECK_FIX.md) | Service endpoint check timing out | Jan 21, 2026 |
| [SILVER_SCHEMAS_UI_IMPROVEMENT.md](SILVER_SCHEMAS_UI_IMPROVEMENT.md) | Button placement and naming improvements | Jan 21, 2026 |
| [PROVIDER_FILTERING_FIX.md](PROVIDER_FILTERING_FIX.md) | Provider filtering and display issues | Jan 21, 2026 |
| [SUSPEND_UPGRADE_RESUME_FIX.md](SUSPEND_UPGRADE_RESUME_FIX.md) | Preserve endpoint URL during deployments | Jan 21, 2026 |
| [FILE_PROCESSING_CANCELED_FIX.md](FILE_PROCESSING_CANCELED_FIX.md) | SQL execution canceled during file processing | Jan 21, 2026 |
| [SPCS_OAUTH_TOKEN_EXPIRATION_FIX.md](SPCS_OAUTH_TOKEN_EXPIRATION_FIX.md) | Getting logged out / token expiration in SPCS | Jan 21, 2026 |
| [CREATE_TABLE_AND_SAMPLE_SCHEMAS_FIX.md](CREATE_TABLE_AND_SAMPLE_SCHEMAS_FIX.md) | Create Table UI + Sample schema generator | Jan 21, 2026 |
| [SCHEMA_EDIT_DELETE_TREE_VIEW_FIX.md](SCHEMA_EDIT_DELETE_TREE_VIEW_FIX.md) | Edit/Delete columns + Tree view structure | Jan 21, 2026 |

### API and Data Processing Fixes

| Document | Description | Date |
|----------|-------------|------|
| [TPA_API_FIX.md](TPA_API_FIX.md) | TPA API table name and platform issues | Jan 20, 2026 |
| [TPA_API_CRUD_FIX.md](TPA_API_CRUD_FIX.md) | TPA API array vs dictionary issue | Jan 21, 2026 |
| [FILE_PROCESSING_FIX.md](FILE_PROCESSING_FIX.md) | File processing error handling improvements | Jan 21, 2026 |
| [FILE_PROCESSING_ERROR_INVESTIGATION.md](FILE_PROCESSING_ERROR_INVESTIGATION.md) | Investigation into file processing errors | Jan 21, 2026 |
| [FILE_PROCESSING_CANCELED_FIX.md](FILE_PROCESSING_CANCELED_FIX.md) | SQL execution canceled error fix | Jan 21, 2026 |

### Connection and Configuration Fixes

| Document | Description | Date |
|----------|-------------|------|
| [USE_DEFAULT_CONNECTION_FIX.md](USE_DEFAULT_CONNECTION_FIX.md) | USE_DEFAULT_CONNECTION configuration fix | Jan 21, 2026 |
| [MULTIPLE_CONNECTIONS_FIX.md](MULTIPLE_CONNECTIONS_FIX.md) | Multiple connections handling fix | Jan 21, 2026 |

### UI and Output Fixes

| Document | Description | Date |
|----------|-------------|------|
| [COLOR_OUTPUT_FIX.md](COLOR_OUTPUT_FIX.md) | ANSI color code rendering fix | Jan 21, 2026 |

---

## Quick Reference

### Most Common Issues

1. **Service already exists error** → See [SERVICE_ALREADY_EXISTS_FIX.md](SERVICE_ALREADY_EXISTS_FIX.md)
2. **Frontend build fails "not found"** → See [DOCKERIGNORE_FRONTEND_FIX.md](DOCKERIGNORE_FRONTEND_FIX.md)
3. **Backend readiness probe failing** → See [READINESS_PROBE_FIX.md](READINESS_PROBE_FIX.md)
4. **Service won't start** → See [TROUBLESHOOT_SERVICE_CREATION.md](TROUBLESHOOT_SERVICE_CREATION.md)
4. **500 errors** → See [TROUBLESHOOTING_500_ERRORS.md](TROUBLESHOOTING_500_ERRORS.md)
5. **Getting logged out** → See [SPCS_OAUTH_TOKEN_EXPIRATION_FIX.md](SPCS_OAUTH_TOKEN_EXPIRATION_FIX.md)
6. **Create Table not working** → See [CREATE_TABLE_AND_SAMPLE_SCHEMAS_FIX.md](CREATE_TABLE_AND_SAMPLE_SCHEMAS_FIX.md)
7. **authenticationPolicy error** → See [AUTHENTICATION_POLICY_FIX.md](AUTHENTICATION_POLICY_FIX.md)
8. **TPA dropdown blank** → See [TPA_API_CRUD_FIX.md](TPA_API_CRUD_FIX.md)
9. **File processing errors** → See [FILE_PROCESSING_FIX.md](FILE_PROCESSING_FIX.md)
10. **SQL execution canceled** → See [FILE_PROCESSING_CANCELED_FIX.md](FILE_PROCESSING_CANCELED_FIX.md)
11. **Connection prompts** → See [MULTIPLE_CONNECTIONS_FIX.md](MULTIPLE_CONNECTIONS_FIX.md)

---

## Fix Categories by Component

### Snowpark Container Services (SPCS)
- Container Deployment Fix
- Troubleshoot Service Creation
- Troubleshooting 500 Errors
- Redeploy Warehouse Fix
- Warehouse Fix
- Authentication Policy Fix
- OAuth Token Expiration Fix

### Backend API
- TPA API Fix
- TPA API CRUD Fix
- File Processing Fix
- File Processing Error Investigation

### Frontend UI
- Create Table and Sample Schemas Fix
- Schema Edit/Delete and Tree View Enhancement

### Deployment Scripts
- USE_DEFAULT_CONNECTION Fix
- Multiple Connections Fix
- Color Output Fix

---

## Related Documentation

- **[../README.md](../README.md)** - Main deployment guide
- **[../QUICK_REFERENCE.md](../QUICK_REFERENCE.md)** - Quick command reference
- **[../../docs/IMPLEMENTATION_LOG.md](../../docs/IMPLEMENTATION_LOG.md)** - Complete project history

---

**Last Updated**: January 21, 2026  
**Total Fixes**: 24
