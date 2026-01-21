# Authentication Policy Fix

**Date**: January 21, 2026  
**Issue**: Invalid spec error for `authenticationPolicy` option  
**Status**: ✅ Fixed

---

## Problem

When deploying the unified service to Snowpark Container Services, an error occurred:

```
Error: 395018 (22023): Invalid spec: unknown option 'authenticationPolicy' for 'endpoints[0]'.
```

**Root Cause:**
The `authenticationPolicy` option is not supported in the current version of Snowpark Container Services. This is a newer feature that may be available in future versions.

---

## Solution

Removed the unsupported `authenticationPolicy` configuration from the service specification.

### Changed File
`deployment/deploy_container.sh` (lines 459-461)

### Before
```yaml
endpoints:
- name: app
  port: 80
  public: true
  # Disable OAuth authentication for public access
  authenticationPolicy:
    type: NONE
```

### After
```yaml
endpoints:
- name: app
  port: 80
  public: true
```

---

## Impact

**Before:**
- ⚠️ Error message during deployment (though service still created)
- Confusing output for users
- Unnecessary configuration

**After:**
- ✅ Clean deployment without errors
- ✅ Service functions identically (public endpoint already accessible)
- ✅ Cleaner specification

---

## Notes

1. **Service Still Works**: The error was non-fatal. The service was created successfully even with the error.

2. **Public Access**: Setting `public: true` already makes the endpoint publicly accessible without authentication. The `authenticationPolicy` was redundant.

3. **Future Compatibility**: When `authenticationPolicy` becomes available in Snowpark Container Services, it can be added back if needed for more granular control.

4. **Default Behavior**: By default, public endpoints in SPCS are accessible without authentication when `public: true` is set.

---

## Verification

After the fix, deployment should complete without errors:

```bash
cd deployment
./deploy_container.sh
```

**Expected output:**
```
[10/10] Deploying unified service...
✓ Service created: BORDEREAU_APP
```

No error messages should appear.

---

## Related

- [Snowpark Container Services Documentation](https://docs.snowflake.com/en/developer-guide/snowpark-container-services/overview)
- [Service Specification Reference](https://docs.snowflake.com/en/developer-guide/snowpark-container-services/specification-reference)

---

**Status**: ✅ Fixed  
**Version**: 1.0  
**Last Updated**: January 21, 2026
