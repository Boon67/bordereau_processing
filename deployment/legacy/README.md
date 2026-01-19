# Legacy Deployment Scripts

This folder contains legacy deployment scripts that are preserved for backward compatibility. These scripts deploy frontend and backend as **separate services** with separate endpoints.

## ⚠️ Not Recommended for New Deployments

For new deployments, use the **unified deployment** in the parent directory:

```bash
cd ..
./deploy_container.sh
```

## Legacy Scripts

### Separate Service Deployment

These scripts deploy frontend and backend as two separate services:

**`deploy_full_stack.sh`**
- Deploys both backend and frontend as separate services
- Includes health checks
- Two separate endpoints (backend + frontend)

**`deploy_snowpark_container.sh`**
- Deploys backend service only
- Backend has public endpoint
- Used for backend-only deployments

**`deploy_frontend_spcs.sh`**
- Deploys frontend service only
- Proxies to external backend URL
- Used for frontend-only deployments

### Legacy Management

**`manage_snowpark_service.sh`**
- Manages backend service only
- View status, logs, restart backend

**`manage_frontend_service.sh`**
- Manages frontend service only
- View status, logs, restart frontend

## Why Legacy?

These scripts are considered legacy because they:

1. **Less Secure**: Backend has public endpoint
2. **More Complex**: Two services to manage
3. **Higher Cost**: Two separate services
4. **Slower**: External network hop for API calls

## Recommended: Unified Deployment

The new unified deployment is better:

```bash
cd ..
./deploy_container.sh
./manage_services.sh status
```

**Benefits:**
- ✅ Single service (simpler)
- ✅ Backend internal-only (more secure)
- ✅ Single endpoint (easier)
- ✅ Localhost communication (faster)
- ✅ Lower cost (shared resources)

## Migration from Legacy

If you have existing separate services:

1. **Deploy with unified script:**
   ```bash
   cd ..
   ./deploy_container.sh
   ```

2. **Test services:**
   ```bash
   ./manage_services.sh status
   ./manage_services.sh health
   ```

3. **Drop old services (optional):**
   ```bash
   ./manage_services.sh drop backend
   ./manage_services.sh drop frontend
   ```

## When to Use Legacy Scripts

Use these scripts only if:
- You need to maintain existing separate services
- You have specific requirements for separate endpoints
- You're troubleshooting legacy deployments

## Support

For questions about:
- **New deployments**: See `../README.md`
- **Container deployment**: See `../deploy_container.sh`
- **Legacy support**: These scripts are maintained but not actively developed

---

**Recommendation**: Migrate to unified deployment for better security, performance, and simplicity.
