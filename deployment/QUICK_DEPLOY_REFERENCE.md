# Quick Deploy Reference Card

**Last Updated**: January 21, 2026

---

## 🚀 Quick Commands

### Deploy Everything (Database + Optional Containers)
```bash
cd deployment && ./deploy.sh
```

### Deploy Database Only (Bronze + Silver + Gold)
```bash
cd deployment && ./deploy.sh
# Answer 'n' when prompted for containers
```

### Deploy Containers Only
```bash
cd deployment && ./deploy_container.sh
```

### Deploy Specific Layer
```bash
cd deployment
./deploy_bronze.sh    # Bronze only
./deploy_silver.sh    # Silver only
./deploy_gold.sh      # Gold only (with bulk optimization ⚡)
```

---

## ⚙️ Configuration

### Quick Setup
```bash
cd deployment
cp custom.config.example custom.config
nano custom.config
```

### Automated Deployment (No Prompts)
```bash
echo "AUTO_APPROVE=true" >> custom.config
echo "USE_DEFAULT_CONNECTION=true" >> custom.config
```

---

## 🔍 Monitoring

### Check Service Status
```bash
cd deployment
./manage_services.sh status
```

### View Logs
```bash
cd deployment
./manage_services.sh logs backend 50   # Last 50 lines
./manage_services.sh logs frontend 50
```

### Health Check
```bash
cd deployment
./manage_services.sh health
```

---

## 🐛 Troubleshooting

### Verbose Deployment
```bash
cd deployment
./deploy.sh -v
```

### Check Connection
```bash
cd deployment
./check_snow_connection.sh
```

### View Deployment Logs
```bash
tail -f deployment/logs/deployment_*.log
```

---

## ⚡ Performance

### Gold Layer (Bulk Optimized)
- **Operations**: 8 (was 69) - **88% reduction**
- **Time**: 2-3s (was 15-20s) - **85% faster**
- **Output**: 20 lines (was 200+) - **90% cleaner**

### Full Deployment
- **Database Layers**: ~2-4 minutes
- **With Containers**: ~7-14 minutes (includes image build)

---

## 📚 Documentation

- [Full Deployment Guide](README.md)
- [Bulk Load Optimization](../gold/BULK_LOAD_OPTIMIZATION.md)
- [Deploy Script Improvements](DEPLOY_SCRIPT_IMPROVEMENTS.md)
- [Complete Optimization Summary](../DEPLOYMENT_OPTIMIZATION_COMPLETE.md)

---

## 🆘 Quick Help

### Common Issues

**Issue**: Deployment hangs
```bash
# Solution: Enable verbose mode
./deploy.sh -v
```

**Issue**: Permission errors
```bash
# Solution: Check roles
snow sql -q "SHOW GRANTS TO USER CURRENT_USER();"
```

**Issue**: Container deployment fails
```bash
# Solution: Check service logs
./manage_services.sh logs backend 100
```

**Issue**: Slow Gold deployment
```bash
# Solution: Verify bulk version is used
grep "2_Gold_Target_Schemas" deploy_gold.sh
# Should show: 2_Gold_Target_Schemas_BULK.sql
```

---

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

**Quick Reference v2.0** | For detailed docs, see [README.md](README.md)
