# Troubleshooting Guide

## Issue: Connection Refused Error (ECONNREFUSED)

### Symptoms
```
Erreur lors de l'initialisation de Keycloak: Error: connect ECONNREFUSED 172.19.0.3:8080
```

### Root Cause
The webapp container tries to connect to Keycloak before it's fully initialized.

### Solution
The code now includes:
1. **Retry mechanism with exponential backoff** in `webapp2/config/keycloak.js` - automatically retries connection up to 10 times
2. **Health check for Keycloak** in `docker-compose.yml` - ensures webapp only starts when Keycloak is ready
3. **Proper dependency management** - webapp now waits for Keycloak health check to pass

### What Changed
- Added retry logic to `initializeKeycloak()` function
- Added Keycloak health check in docker-compose.yml
- Changed webapp dependency from basic `depends_on` to `condition: service_healthy`

---

## Issue: Invalid Client Credentials

### Symptoms
```
OPError: unauthorized_client (Invalid client or Invalid client credentials)
Keycloak log: type="CODE_TO_TOKEN_ERROR", error="invalid_client_credentials"
```

### Root Cause
This happens when:
1. Keycloak's database has an old realm configuration with different client credentials
2. The realm import is skipped because the realm already exists: `Realm 'projetcis' already exists. Import skipped`

### Solution

#### Option 1: Reset Keycloak Data (Recommended)
Run the reset script to clear all Keycloak data and force a fresh import:

```bash
./reset-keycloak.sh
```

Or manually:
```bash
docker-compose down
docker volume rm equipe1_keycloak-postgres
docker-compose up -d
```

#### Option 2: Update Client Secret in Keycloak Admin Console
1. Go to http://localhost:8080
2. Login with admin/admin
3. Navigate to: Clients → webapp → Credentials tab
4. Set the client secret to: `webapp-client-secret-123`
5. Click Save
6. Restart the webapp: `docker-compose restart webapp`

#### Option 3: Check Environment Variables
Verify that the client secret in docker-compose.yml matches the realm.json:

```bash
# Check environment variable
docker-compose exec webapp printenv CLIENT_SECRET

# Should output: webapp-client-secret-123
```

---

## Why It Works on Another PC But Not Yours

Docker volumes persist data between container restarts. If you've run this project before with different settings:
- Your PC has old Keycloak data in a Docker volume
- The other PC either has the correct data or is running fresh

The solution is to reset the Keycloak data volume as described above.

---

## Startup Sequence

With the fixes, the correct startup sequence is:

1. **PostgreSQL starts** → Health check passes
2. **Keycloak starts** → Waits for PostgreSQL → Imports realm → Health check passes (may take 30-60 seconds)
3. **Webapp starts** → Waits for Keycloak health check → Retries connection if needed → Connects successfully
4. **Device-app starts** → Same as webapp

---

## Quick Reference

### Check Service Status
```bash
docker-compose ps
```

### View Logs
```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f webapp
docker-compose logs -f keycloak
```

### Restart Services
```bash
# Restart webapp only
docker-compose restart webapp

# Restart everything
docker-compose restart

# Full rebuild and restart
docker-compose down
docker-compose up -d --build
```

### Clean Start
```bash
# Remove all containers, networks, and volumes
docker-compose down -v

# Rebuild and start
docker-compose up -d --build
```

---

## Configuration Reference

### Client Credentials (realm.json)
- **Client ID**: `webapp`
- **Client Secret**: `webapp-client-secret-123`
- **Authentication Type**: `client-secret`
- **Public Client**: `false`

### Environment Variables (docker-compose.yml)
- `KEYCLOAK_URL`: `http://localhost:8080` (public URL for browser redirects)
- `KEYCLOAK_INTERNAL_URL`: `http://keycloak:8080` (internal Docker network URL)
- `CLIENT_ID`: `webapp`
- `CLIENT_SECRET`: `webapp-client-secret-123`
- `REALM`: `projetcis`
- `REDIRECT_URI`: `https://localhost:3000/auth/callback`

---

## Still Having Issues?

1. Check that all three values match:
   - `realm.json`: `"secret": "webapp-client-secret-123"`
   - `docker-compose.yml`: `CLIENT_SECRET=webapp-client-secret-123`
   - Keycloak Admin UI: Clients → webapp → Credentials → Client Secret

2. Ensure Keycloak imported the realm:
   ```bash
   docker-compose logs keycloak | grep -i import
   # Should see: "Import finished successfully"
   # Should NOT see: "Import skipped" (unless you want to keep existing config)
   ```

3. Verify client configuration in Keycloak:
   - Go to http://localhost:8080
   - Login: admin/admin
   - Clients → webapp → Settings
   - Verify "Client Authenticator" is set to "Client Id and Secret"
   - Verify "Standard Flow Enabled" is ON

4. If all else fails, reset everything:
   ```bash
   docker-compose down -v
   docker system prune -f
   docker-compose up -d --build
   ```
