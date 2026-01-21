# Fix Summary: Connection Error Resolution

## Problem Statement
The application was experiencing connection errors on startup:
- `ECONNREFUSED 172.19.0.3:8080` - webapp couldn't connect to Keycloak
- `unauthorized_client (Invalid client or Invalid client credentials)` - authentication failures
- Continuous restart loop of the webapp container

## Root Causes Identified

### 1. Timing Issue
- **Problem**: Webapp started immediately after Keycloak container started, but before Keycloak service was ready
- **Impact**: Connection refused errors during initialization
- **Duration**: Keycloak takes 30-60 seconds to fully initialize

### 2. Missing Health Check
- **Problem**: Docker Compose `depends_on` only waited for container start, not service readiness
- **Impact**: Webapp attempted connections too early
- **Result**: Multiple failed attempts and restart loops

### 3. Stale Keycloak Data
- **Problem**: Docker volume contained old realm configuration with different client credentials
- **Impact**: "Import skipped" message, mismatched client secrets
- **Why**: Works on other PC but not yours - different volume data

## Solutions Implemented

### 1. Retry Mechanism with Exponential Backoff
**File**: `webapp2/config/keycloak.js`

Added intelligent retry logic:
- Up to 10 retry attempts
- Exponential backoff starting at 2 seconds
- Delay increases by 1.5x each attempt
- Clear console feedback during retries

```javascript
// New functions added:
- sleep(ms) - for delays
- retryWithBackoff(fn, maxRetries, initialDelay) - retry wrapper
- Updated initializeKeycloak() to use retryWithBackoff
```

**Benefits**:
- Automatically handles Keycloak startup delays
- No manual intervention needed
- Clear logging of retry attempts

### 2. Keycloak Health Check
**File**: `docker-compose.yml`

Added comprehensive health check to Keycloak service:
```yaml
healthcheck:
  test: HTTP request to /health/ready endpoint
  interval: 10s
  timeout: 5s
  retries: 10
  start_period: 60s
```

**Benefits**:
- Docker knows when Keycloak is truly ready
- Dependent services wait for actual readiness
- Prevents premature connection attempts

### 3. Improved Service Dependencies
**File**: `docker-compose.yml`

Updated webapp and device-app dependencies:
```yaml
depends_on:
  keycloak:
    condition: service_healthy  # Changed from just "depends_on: keycloak"
```

Reduced restart limits:
- webapp: `on-failure:5` (was 30)
- device-app: `on-failure:5` (was 10)

**Benefits**:
- Services start only when Keycloak is healthy
- Fewer unnecessary restart attempts
- Faster failure detection if real issues exist

### 4. Reset Script
**File**: `reset-keycloak.sh`

Created helper script to resolve stale data issues:
- Stops all containers
- Removes Keycloak data volume
- Restarts with fresh realm import

**Benefits**:
- Easy resolution for "client credentials" errors
- Forces fresh realm configuration
- Simple one-command fix

### 5. Documentation
**Files**: `TROUBLESHOOTING.md`, `FIX_SUMMARY.md`

Comprehensive documentation covering:
- Problem symptoms and causes
- Step-by-step solutions
- Configuration reference
- Common troubleshooting scenarios

## Changes Summary

### Modified Files
1. **webapp2/config/keycloak.js**
   - Added `sleep()` helper function
   - Added `retryWithBackoff()` function
   - Modified `initializeKeycloak()` to use retry mechanism

2. **docker-compose.yml**
   - Added health check to `keycloak` service
   - Updated `webapp` service dependency to use health condition
   - Updated `device-app` service dependency to use health condition
   - Reduced restart attempt limits

### New Files
1. **reset-keycloak.sh** - Helper script to reset Keycloak data
2. **TROUBLESHOOTING.md** - Detailed troubleshooting guide
3. **FIX_SUMMARY.md** - This file, explaining all changes

## Testing the Fix

### Expected Behavior After Fix:
1. Start services: `docker-compose up -d`
2. PostgreSQL starts first, becomes healthy
3. Keycloak starts, waits for PostgreSQL, imports realm, becomes healthy (30-60s)
4. Webapp waits for Keycloak health check, then connects successfully
5. No connection refused errors
6. No restart loops
7. Successful authentication

### If You Still See Errors:
1. Check if it's the stale data issue: `docker-compose logs keycloak | grep "Import skipped"`
2. If yes, run: `./reset-keycloak.sh`
3. Or manually: `docker-compose down && docker volume rm equipe1_keycloak-postgres && docker-compose up -d`

### Verification Commands:
```bash
# Check service health
docker-compose ps

# Watch startup process
docker-compose logs -f

# Verify Keycloak is healthy
docker inspect keycloak --format='{{.State.Health.Status}}'

# Check webapp logs for successful connection
docker-compose logs webapp | grep "Client OpenID Connect initialisé"
```

## Configuration Consistency Check

Ensure these three locations have matching client credentials:

1. **realm.json** (line 19):
   ```json
   "secret": "webapp-client-secret-123"
   ```

2. **docker-compose.yml** (line 52):
   ```yaml
   CLIENT_SECRET=webapp-client-secret-123
   ```

3. **Keycloak Admin UI**:
   - URL: http://localhost:8080
   - Login: admin/admin
   - Navigate: Clients → webapp → Credentials
   - Client Secret: `webapp-client-secret-123`

## Performance Impact

- **Startup time**: Slightly longer (waits for Keycloak health check)
- **Reliability**: Significantly improved (no more restart loops)
- **Resource usage**: Reduced (fewer failed connection attempts)
- **Developer experience**: Much better (consistent behavior)

## Why This Works on Other PCs

The key difference is the Docker volume data:
- **Fresh setup**: Realm imports correctly with proper credentials
- **Your PC**: Old volume data with potentially different credentials
- **Solution**: Reset the volume to force fresh import

## Maintenance Notes

If you modify `webapp2/imports/realm.json`:
1. The changes won't apply automatically if realm exists
2. You must either:
   - Run `./reset-keycloak.sh` to force reimport
   - Manually update via Keycloak Admin UI
   - Delete the volume: `docker volume rm equipe1_keycloak-postgres`

## Future Improvements (Optional)

Consider these additional enhancements:
1. Add health check endpoint to webapp service
2. Implement graceful shutdown handling
3. Add connection pool for database
4. Monitor health check metrics
5. Add automated tests for authentication flow

## References

- OpenID Connect: https://openid.net/connect/
- Keycloak Documentation: https://www.keycloak.org/documentation
- Docker Compose Health Checks: https://docs.docker.com/compose/compose-file/05-services/#healthcheck
- Node.js openid-client: https://github.com/panva/node-openid-client
