#!/bin/bash

echo "========================================="
echo "Device App Diagnostic Script"
echo "========================================="
echo ""

echo "1. Checking if device-app container is running..."
docker ps -a | grep cis-device-app
echo ""

echo "2. Device-app container logs (last 30 lines)..."
docker logs cis-device-app 2>&1 | tail -30
echo ""

echo "3. Checking if port 4000 is listening inside container..."
docker exec cis-device-app netstat -tulpn 2>/dev/null | grep 4000 || echo "netstat not available, trying curl..."
echo ""

echo "4. Testing health endpoint from inside container..."
docker exec cis-device-app wget -qO- http://localhost:4000/health 2>&1 || echo "Health check failed"
echo ""

echo "5. Checking environment variables..."
docker exec cis-device-app printenv | grep -E "(KEYCLOAK|REALM|CLIENT|PORT)"
echo ""

echo "6. Testing from host machine..."
curl -s http://localhost:4000/health || echo "Cannot reach from host"
echo ""

echo "========================================="
echo "Diagnostic complete"
echo "========================================="
