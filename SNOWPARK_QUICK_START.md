# Snowpark Container Services - Quick Start

Deploy the Bordereau Processing Pipeline to Snowpark Container Services in minutes.

## Prerequisites Check

```bash
# Check if Snow CLI is installed
snow --version

# Check if Docker is installed
docker --version

# Test Snowflake connection
snow connection test --connection DEPLOYMENT
```

If any are missing, see [SNOWPARK_CONTAINER_DEPLOYMENT.md](./SNOWPARK_CONTAINER_DEPLOYMENT.md) for installation instructions.

## One-Command Deployment

```bash
./deploy_snowpark_container.sh
```

This will:
- ✅ Create compute pool
- ✅ Create image repository
- ✅ Build Docker image
- ✅ Push to Snowflake registry
- ✅ Deploy service
- ✅ Show endpoint URL

**Expected time**: 10-15 minutes

## Verify Deployment

```bash
# Check service status
./manage_snowpark_service.sh status

# Get service endpoint
./manage_snowpark_service.sh endpoint

# Test the API
ENDPOINT=$(./manage_snowpark_service.sh endpoint | grep -o 'https://[^"]*')
curl $ENDPOINT/api/health
```

## Common Commands

```bash
# Show all status information
./manage_snowpark_service.sh all

# View logs (last 100 lines)
./manage_snowpark_service.sh logs 100

# Restart service
./manage_snowpark_service.sh restart

# Suspend service (save costs)
./manage_snowpark_service.sh suspend

# Resume service
./manage_snowpark_service.sh resume
```

## Troubleshooting

### Service Won't Start

```bash
# Check logs for errors
./manage_snowpark_service.sh logs 500

# Check compute pool status
./manage_snowpark_service.sh pool-status
```

### Can't Connect to Snowflake

```bash
# Test connection
snow connection test --connection DEPLOYMENT

# Re-configure if needed
snow connection add
```

### Docker Build Fails

```bash
# Check Docker is running
docker ps

# Check disk space
df -h

# Clean up old images
docker system prune -a
```

## Custom Configuration

Deploy with custom settings:

```bash
./deploy_snowpark_container.sh \
    --account YOUR_ACCOUNT \
    --user YOUR_USER \
    --database YOUR_DATABASE \
    --compute-pool MY_POOL \
    --service MY_SERVICE
```

## Next Steps

- Read full documentation: [SNOWPARK_CONTAINER_DEPLOYMENT.md](./SNOWPARK_CONTAINER_DEPLOYMENT.md)
- Monitor service: `./manage_snowpark_service.sh all`
- Update service: Rebuild and redeploy with same command
- Scale service: Adjust MIN/MAX instances in SQL

## Cost Management

```sql
-- Suspend when not in use
ALTER SERVICE BORDEREAU_SERVICE SUSPEND;

-- Resume when needed
ALTER SERVICE BORDEREAU_SERVICE RESUME;

-- Or use the script
./manage_snowpark_service.sh suspend
./manage_snowpark_service.sh resume
```

## Support

For detailed help:
- Full deployment guide: [SNOWPARK_CONTAINER_DEPLOYMENT.md](./SNOWPARK_CONTAINER_DEPLOYMENT.md)
- Service management: `./manage_snowpark_service.sh help`
- Snowflake docs: https://docs.snowflake.com/en/developer-guide/snowpark-container-services
