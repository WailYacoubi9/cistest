# Device App Troubleshooting Guide

## Issue: localhost:4000 doesn't work

### Quick Diagnostic

Run the diagnostic script on Windows PowerShell or Git Bash:

**On Linux/Mac/Git Bash:**
```bash
./diagnose-device-app.sh
```

**On Windows PowerShell:**
```powershell
# Check if container is running
docker ps -a | Select-String "cis-device-app"

# View logs
docker logs cis-device-app

# Test health endpoint
curl http://localhost:4000/health
```

### Common Issues and Solutions

#### 1. Container Not Running

**Symptom:** `docker ps` doesn't show cis-device-app

**Solution:**
```bash
# Check why it's not running
docker logs cis-device-app

# Restart it
docker-compose up -d device-app

# Rebuild if needed
docker-compose up -d --build device-app
```

#### 2. Application Crashed at Startup

**Symptom:** Container keeps restarting or exits

**Check logs:**
```bash
docker logs cis-device-app --tail 50
```

**Common causes:**
- Missing dependencies (run `docker-compose build device-app`)
- Port conflict (check if something else uses port 4000)
- Environment variable issues

#### 3. Port Not Accessible from Host

**Symptom:** Container is running but `http://localhost:4000` doesn't respond

**Check port mapping:**
```bash
docker ps | grep device-app
# Should show: 0.0.0.0:4000->4000/tcp
```

**Check if app is listening:**
```bash
docker exec cis-device-app netstat -tulpn | grep 4000
# OR
docker exec cis-device-app wget -qO- http://localhost:4000/health
```

**Solution if port mapping is wrong:**
```bash
docker-compose down
docker-compose up -d
```

#### 4. HTTPS Certificate Issues

The device-app tries to use HTTPS if certificates are found in the `certs/` directory.

**Check server logs:**
```bash
docker logs cis-device-app | grep -i "https\|http\|server"
```

**Expected output:**
- With certs: `Device App HTTPS démarrée sur https://localhost:4000`
- Without certs: `Device App HTTP démarrée sur http://localhost:4000`

**If HTTPS fails:**
The app should automatically fall back to HTTP. If it doesn't:
1. Remove old certificates from `device-app/certs/`
2. Rebuild: `docker-compose up -d --build device-app`

#### 5. Environment Variable Issues

**Fixed in latest version:** Environment variable mismatch for REALM

**Verify environment variables:**
```bash
docker exec cis-device-app printenv | grep -E "(KEYCLOAK|REALM|CLIENT)"
```

**Should show:**
```
KEYCLOAK_URL=http://localhost:8080
KEYCLOAK_INTERNAL_URL=http://keycloak:8080
REALM=projetcis
CLIENT_ID=devicecis
PORT=4000
```

### Testing the Device App

Once the container is running:

1. **Access the UI:**
   - HTTP: http://localhost:4000
   - HTTPS: https://localhost:4000 (if certificates are present)

2. **Test health endpoint:**
   ```bash
   curl http://localhost:4000/health
   # Expected: {"status":"OK","service":"device-app"}
   ```

3. **Check status endpoint:**
   ```bash
   curl http://localhost:4000/status
   # Expected: {"authenticated":false,"pending":false}
   ```

### Full Reset

If nothing works, do a full reset:

```bash
# Stop all services
docker-compose down

# Remove device-app image
docker rmi equipe1-device-app

# Rebuild and restart
docker-compose up -d --build device-app

# Watch logs
docker-compose logs -f device-app
```

### Understanding Device Flow

The device-app implements OAuth 2.0 Device Authorization Grant:

1. User clicks "Start Authentication" at http://localhost:4000
2. App requests a device code from Keycloak
3. User sees a code and URL
4. User enters the code at the webapp (https://localhost:3000/activate)
5. App polls Keycloak until user authorizes
6. App receives access token

### Architecture

```
Device App (port 4000)
    ↓
    Makes HTTP requests to Keycloak (internal: http://keycloak:8080)
    ↓
    User opens webapp (https://localhost:3000/activate)
    ↓
    User authorizes device
    ↓
    Device app receives token
```

### Key Differences from Webapp

- **Device-app**: Doesn't need to connect to Keycloak at startup
- **Webapp**: Connects to Keycloak during initialization

This means:
- Device-app should start faster
- Device-app won't have retry messages on startup
- Device-app only connects to Keycloak when user initiates device flow

### Still Having Issues?

1. Provide the output of:
   ```bash
   docker ps -a | grep device
   docker logs cis-device-app
   docker exec cis-device-app printenv
   ```

2. Check if port 4000 is already in use:
   ```bash
   # Windows
   netstat -ano | findstr :4000

   # Linux/Mac
   lsof -i :4000
   ```

3. Try accessing from inside the container:
   ```bash
   docker exec cis-device-app wget -qO- http://localhost:4000/health
   ```

4. Check firewall settings (Windows):
   - Windows Firewall might block port 4000
   - Docker Desktop settings → Resources → check port forwarding
