# Container Deployment Enhancement

## Overview

Enhanced the `deploy_container.sh` script to wait for service URLs to be actually accessible before completing deployment, providing better feedback on service readiness.

## Changes Made

### 1. New Function: `wait_for_service_ready()`

Added a new function that actively tests the service endpoint to verify it's accessible:

**Features**:
- Tests both root endpoint (`/`) and API health endpoint (`/api/health`)
- Supports both `curl` and `wget` for maximum compatibility
- Configurable retry logic (30 attempts with 10-second intervals = 5 minutes max)
- Provides detailed progress feedback
- Graceful handling when service is slow to initialize

**Behavior**:
```bash
# Tests HTTP response codes
- 200, 301, 302 = Success (service is accessible)
- 000 = Connection timeout/network error
- Other codes = Service responding but may not be ready
```

### 2. Enhanced `get_service_endpoint()`

Updated to distinguish between "URL obtained" and "service accessible":
- Now logs "Public endpoint URL obtained" when URL is retrieved
- Separate verification step confirms accessibility

### 3. Updated `print_summary()`

Enhanced summary output to show service accessibility status:
- ✓ Green checkmark if service is accessible
- ⚠ Yellow warning if URL is published but not yet accessible
- Clear guidance on what to do if service is still initializing

### 4. Updated Main Flow

```bash
main() {
    # ... existing steps ...
    get_service_endpoint      # Get the URL
    wait_for_service_ready    # NEW: Wait for URL to be accessible
    print_summary             # Show final status
}
```

## Usage

The enhancement is automatic - no changes needed to how you run the script:

```bash
cd deployment
./deploy_container.sh
```

## Example Output

### During Deployment:
```
[INFO] Getting service endpoint...
[SUCCESS] Public endpoint URL obtained: https://abc123.snowflakecomputing.app
[INFO] Internal endpoint: https://bordereau-app.internal.snowflakecomputing.com

[INFO] Waiting for service to be accessible...
[INFO] Testing URL: https://abc123.snowflakecomputing.app
[INFO] This may take several minutes as the service initializes...
[INFO] Service not yet accessible (attempt 1/30)
[INFO] Waiting 10 seconds before next attempt...
[INFO] Service not yet accessible (attempt 2/30)
[INFO] Waiting 10 seconds before next attempt...
[SUCCESS] Service is accessible! (HTTP 200)
[INFO] Testing API health endpoint...
[SUCCESS] API health check passed! (HTTP 200)
```

### In Summary:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  📍 ENDPOINTS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  🌐 Public URL (Internet-accessible):
    https://abc123.snowflakecomputing.app

  ✓ Service is accessible and responding

  API Health Check:
    https://abc123.snowflakecomputing.app/api/health
```

## Timeout Behavior

**Maximum Wait Time**: 5 minutes (30 attempts × 10 seconds)

If service is not accessible after 5 minutes:
- Script completes with warning message
- Provides instructions for manual verification
- This is normal for first deployment or large services

**Why 5 minutes?**
- Container services can take 2-4 minutes to fully initialize
- Includes time for:
  - Container image pull
  - Container startup
  - Application initialization
  - Health check stabilization
  - Ingress URL routing setup

## Benefits

1. **Immediate Feedback**: Know right away if service is accessible
2. **Reduced Confusion**: Clear distinction between "URL published" and "service ready"
3. **Better Debugging**: Detailed progress logs help identify issues
4. **Automated Verification**: No need to manually test URLs
5. **Graceful Handling**: Works even if service is slow to start

## Error Handling

The script handles various scenarios:

1. **Service accessible immediately**: Completes quickly with success message
2. **Service slow to start**: Waits patiently with progress updates
3. **Service never accessible**: Completes with warning and troubleshooting steps
4. **No curl/wget available**: Skips accessibility check with warning
5. **Network issues**: Reports connection errors clearly

## Troubleshooting

If the script reports service is not accessible:

1. **Wait a few more minutes** - First deployment can take longer
2. **Check service status**:
   ```bash
   cd deployment
   ./manage_services.sh status
   ```
3. **View service logs**:
   ```bash
   ./manage_services.sh logs frontend 100
   ./manage_services.sh logs backend 100
   ```
4. **Manually test URL**:
   ```bash
   curl https://your-service-url.snowflakecomputing.app
   curl https://your-service-url.snowflakecomputing.app/api/health
   ```
5. **Check compute pool**:
   ```bash
   snow spcs compute-pool list --connection DEPLOYMENT
   ```

## Configuration

You can adjust the wait behavior by modifying these variables in `wait_for_service_ready()`:

```bash
local max_attempts=30      # Number of retry attempts
local wait_seconds=10      # Seconds between attempts
```

For example, to wait up to 10 minutes:
```bash
local max_attempts=60      # 60 attempts
local wait_seconds=10      # 10 seconds = 10 minutes total
```

## Testing

To test the enhancement:

1. Deploy a service:
   ```bash
   cd deployment
   ./deploy_container.sh
   ```

2. Observe the "Waiting for service to be accessible..." phase

3. Verify the summary shows service status

4. Test the URL manually to confirm:
   ```bash
   curl https://your-service-url.snowflakecomputing.app
   ```

## Compatibility

- **Requires**: `curl` or `wget` (most systems have one or both)
- **Works with**: All Snowflake accounts and regions
- **Tested on**: macOS, Linux
- **Windows**: Should work with Git Bash or WSL

## Future Enhancements

Possible future improvements:

1. **Parallel health checks**: Test multiple endpoints simultaneously
2. **Exponential backoff**: Increase wait time between retries
3. **Service-specific timeouts**: Different timeouts for different services
4. **Detailed health metrics**: Report response time, latency, etc.
5. **Email/Slack notifications**: Alert when service is ready

## Related Files

- `deploy_container.sh` - Main deployment script (enhanced)
- `manage_services.sh` - Service management utilities
- `docker/README.md` - Container deployment documentation

## Summary

This enhancement ensures that `deploy_container.sh` not only deploys the service and obtains the URL, but also verifies that the service is actually accessible before completing. This provides a better user experience and reduces confusion about service readiness.

**Key Improvement**: Script now waits for real accessibility, not just URL publication.
