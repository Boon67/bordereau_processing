# Deployment Quick Reference

**Last Updated**: January 21, 2026  
**Version**: 2.0

## 🚀 Quick Start

```bash
# Option 1: Deploy everything (database + optional containers)
cd deployment
./deploy.sh

# Option 2: Deploy database only, then containers separately
cd deployment
./deploy.sh        # Answer 'n' when prompted for containers
./deploy_container.sh  # Deploy containers later

# Option 3: Check status
./manage_services.sh status
```

## 📋 Core Scripts

| Script | Purpose | When to Use |
|--------|---------|-------------|
| `deploy.sh` | Deploy Bronze + Silver + Gold layers (+ optional containers) | First time setup or database updates |
| `deploy_bronze.sh` | Deploy Bronze layer only | Bronze layer updates |
| `deploy_silver.sh` | Deploy Silver layer only | Silver layer updates |
| `deploy_gold.sh` | Deploy Gold layer only (⚡ bulk optimized) | Gold layer updates |
| `deploy_container.sh` | Deploy unified SPCS service | Deploy/update frontend + backend |
| `manage_services.sh` | Manage SPCS services | Check status, view logs, restart |
| `undeploy.sh` | Remove all resources | Cleanup or reset |

## 🔧 Common Commands

### Deployment

```bash
# Full deployment (database + optional containers)
./deploy.sh  # Prompts for container deployment

# Automated deployment (no prompts)
echo "AUTO_APPROVE=true" >> custom.config
echo "USE_DEFAULT_CONNECTION=true" >> custom.config
./deploy.sh

# Database only
./deploy.sh  # Answer 'n' when prompted

# Containers only
./deploy_container.sh

# Specific layers
./deploy_bronze.sh  # Bronze only
./deploy_silver.sh  # Silver only
./deploy_gold.sh    # Gold only (⚡ 88% faster with bulk optimization)
```

### Service Management

```bash
# Check status
./manage_services.sh status

# View logs
./manage_services.sh logs backend 100
./manage_services.sh logs frontend 100
./manage_services.sh logs all 50

# Health check
./manage_services.sh health

# Restart
./manage_services.sh restart all
./manage_services.sh restart backend
./manage_services.sh restart frontend

# Update with new image
./manage_services.sh restart-image all
```

### Utilities

```bash
# Test connection
./check_snow_connection.sh

# Test deployment (without deploying)
./test_deploy_container.sh

# Remove everything
./undeploy.sh
```

## 📁 Script Locations

### Main Scripts (Recommended)
```
deployment/
├── deploy.sh                    ⭐ Database deployment
├── deploy_container.sh          ⭐ Container deployment
└── manage_services.sh           ⭐ Service management
```

### Legacy Scripts (Not Recommended)
```
deployment/legacy/
├── deploy_full_stack.sh         ⚠️ Separate services
├── deploy_frontend_spcs.sh      ⚠️ Frontend only
└── deploy_snowpark_container.sh ⚠️ Backend only
```

## 🎯 Deployment Scenarios

### Scenario 1: New Project Setup

```bash
cd deployment

# 1. Deploy database
./deploy.sh

# 2. Deploy containers
./deploy_container.sh

# 3. Verify
./manage_services.sh status
./manage_services.sh health
```

### Scenario 2: Update Backend Code

```bash
cd deployment

# Rebuild and redeploy
./deploy_container.sh

# Verify
./manage_services.sh logs backend 100
```

### Scenario 3: Update Frontend Code

```bash
cd deployment

# Rebuild and redeploy
./deploy_container.sh

# Verify
./manage_services.sh logs frontend 100
```

### Scenario 4: Update Database Schema

```bash
cd deployment

# Update Bronze layer
./deploy_bronze.sh

# Or update Silver layer
./deploy_silver.sh

# Or update both
./deploy.sh
```

### Scenario 5: Troubleshooting

```bash
cd deployment

# Check service status
./manage_services.sh status

# View recent logs
./manage_services.sh logs all 200

# Check health
./manage_services.sh health

# Restart if needed
./manage_services.sh restart all
```

## 🔍 Service Information

### Get Service Endpoint

```bash
# Using manage script
./manage_services.sh endpoints

# Or using snow CLI
snow sql -q "SHOW ENDPOINTS IN SERVICE BORDEREAU_PROCESSING_PIPELINE.PUBLIC.BORDEREAU_APP" \
  --connection DEPLOYMENT
```

### Get Service Status

```bash
# Using manage script
./manage_services.sh status

# Or using snow CLI
snow spcs service status BORDEREAU_APP \
  --connection DEPLOYMENT \
  --database BORDEREAU_PROCESSING_PIPELINE \
  --schema PUBLIC
```

## 📊 Current Deployment

**Service**: `BORDEREAU_APP`  
**Endpoint**: `https://jscmn2pb-sfsenorthamerica-tboon-aws2.snowflakecomputing.app`  
**Status**: ✅ Running  
**Containers**:
- Backend (FastAPI) - Port 8000 (internal)
- Frontend (React + Nginx) - Port 80 (public)

## 🆘 Troubleshooting

### Service Won't Start

```bash
# Check logs
./manage_services.sh logs all 200

# Check compute pool
snow sql -q "DESCRIBE COMPUTE POOL BORDEREAU_COMPUTE_POOL" --connection DEPLOYMENT

# Restart service
./manage_services.sh restart all
```

### Endpoint Not Available

```bash
# Wait 2-3 minutes for provisioning
sleep 180

# Check again
./manage_services.sh endpoints
```

### Connection Issues

```bash
# Test connection
./check_snow_connection.sh

# Check credentials
snow connection test --connection DEPLOYMENT
```

## ⚡ Performance (Gold Layer Optimization)

**Bulk Load Optimization:**
- **Operations**: 8 (was 69) - **88% reduction**
- **Time**: 2-3s (was 15-20s) - **85% faster**
- **Output**: 20 lines (was 200+) - **90% cleaner**

**Full Deployment Time:**
- **Database Layers**: ~2-4 minutes
- **With Containers**: ~7-14 minutes (includes image build)

## 📚 Documentation

- **Full Guide**: [README.md](README.md)
- **Bulk Optimization**: [../gold/BULK_LOAD_OPTIMIZATION.md](../gold/BULK_LOAD_OPTIMIZATION.md)
- **Script Improvements**: [DEPLOY_SCRIPT_IMPROVEMENTS.md](DEPLOY_SCRIPT_IMPROVEMENTS.md)
- **Legacy Guide**: [legacy/README.md](legacy/README.md)

## ⚡ Pro Tips

1. **Always test connection first**: `./check_snow_connection.sh`
2. **Use manage_services.sh for everything**: It's the unified tool
3. **Check logs when troubleshooting**: `./manage_services.sh logs all 200`
4. **Endpoint takes 2-3 minutes**: Be patient after deployment
5. **Keep legacy scripts**: They're in `legacy/` for reference

## 🔗 Quick Links

- **Service Endpoint**: https://jscmn2pb-sfsenorthamerica-tboon-aws2.snowflakecomputing.app
- **API Health**: https://jscmn2pb-sfsenorthamerica-tboon-aws2.snowflakecomputing.app/api/health
- **Main README**: [../README.md](../README.md)
- **User Guide**: [../docs/USER_GUIDE.md](../docs/USER_GUIDE.md)

## 🎯 Next Steps After Deployment

### 1. Upload Sample Data
```bash
snow stage put sample_data/claims_data/provider_a/*.csv \
    @BRONZE.SRC/provider_a/ \
    --connection DEPLOYMENT
```

### 2. Resume Tasks (Optional)
```bash
snow sql --connection DEPLOYMENT -q "
    USE DATABASE BORDEREAU_PROCESSING_PIPELINE;
    USE SCHEMA BRONZE;
    ALTER TASK discover_files_task RESUME;
"
```

### 3. Access Application (If Containers Deployed)
```bash
# Get frontend URL
snow spcs service list-endpoints BORDEREAU_APP --connection DEPLOYMENT

# Open in browser
# https://xxx-xxx-xxx.snowflakecomputing.app
```

---

**Quick Reference Version**: 2.0  
**Last Updated**: January 21, 2026  
**Status**: ✅ Current
