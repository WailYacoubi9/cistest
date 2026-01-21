#!/bin/bash

# Script to reset Keycloak and force a fresh realm import
# This is useful when the realm configuration has changed

echo "⚠️  This will delete all Keycloak data and force a fresh realm import"
echo "Press Ctrl+C to cancel, or Enter to continue..."
read

echo "Stopping containers..."
docker-compose down

echo "Removing Keycloak data volume..."
docker volume rm equipe1_keycloak-postgres 2>/dev/null || echo "Volume not found, continuing..."

echo "Recreating containers with fresh data..."
docker-compose up -d

echo "✅ Done! Keycloak will reimport the realm configuration on startup."
echo "Check logs with: docker-compose logs -f keycloak"
