# 🧪 Tests - OAuth2 Device Flow

Guide de test pour l'application OAuth2 Device Flow (Keycloak + WebApp + Device-app).

---

## 📋 Table des matières

1. [Tests automatisés](#tests-automatisés)
2. [Tests manuels](#tests-manuels)
3. [Scénarios de test](#scénarios-de-test)
4. [Checklist complète](#checklist-complète)
5. [Dépannage](#dépannage)

---

## 🤖 Tests automatisés

### Prérequis

Avant de lancer les tests, assurez-vous que tous les services sont démarrés :

```bash
# Terminal 1: Keycloak
docker start keycloak-dev
# OU
cd keycloak && docker-compose up -d

# Terminal 2: Device-app
cd device-app
npm start

# Terminal 3: WebApp
cd webapp2
npm start
```

Vérifiez que les services répondent :
- Keycloak: http://localhost:8080
- Device-app: https://localhost:4000
- WebApp: https://localhost:3000

---

### Test 1: Script Bash (test-flow.sh)

**Rapide et léger** - Teste les endpoints de base avec curl.

```bash
# Lancer le test
./tests/test-flow.sh

# OU si pas exécutable
chmod +x tests/test-flow.sh
./tests/test-flow.sh
```

**Ce qui est testé :**
- ✅ Keycloak accessible
- ✅ WebApp accessible
- ✅ Device-app accessible
- ✅ `/api/status` retourne 404 (vérification architecture)
- ✅ `/activate` accessible
- ✅ `/profile` redirige sans auth
- ✅ `/devices` redirige sans auth
- ✅ Device Flow endpoint configuré dans Keycloak

**Durée :** ~5 secondes

---

### Test 2: Script Node.js (test-integration.js)

**Complet et détaillé** - Teste l'intégration avec axios.

```bash
# Installer les dépendances si besoin
npm install axios

# Lancer le test
node tests/test-integration.js

# OU si exécutable
./tests/test-integration.js
```

**Ce qui est testé :**
- ✅ Keycloak health check
- ✅ WebApp accessible
- ✅ Device-app health check
- ✅ Device Flow - Demande de code
- ✅ Architecture - `/api/status` supprimé
- ✅ WebApp - Authentification requise
- ✅ WebApp - Page `/activate` accessible
- ✅ Keycloak - Endpoints OAuth2 configurés

**Durée :** ~10 secondes

**Sortie :**
```
╔════════════════════════════════════════════════════════════╗
║   Tests d'intégration OAuth2 Device Flow                  ║
║   Projet CIS - Keycloak + WebApp + Device-app             ║
╚════════════════════════════════════════════════════════════╝

============================================================
TEST 1: Services disponibles
============================================================

✅ Keycloak est accessible (GET /.well-known/openid-configuration)
✅ WebApp est accessible (GET / → 200)
✅ Device-app est accessible (GET /health)

============================================================
RÉSUMÉ DES TESTS
============================================================

✅ Tests réussis: 9
❌ Tests échoués: 0
📊 Taux de réussite: 100.0%

🎉 Tous les tests passent ! L'architecture est correcte.
```

---

## 🖐️ Tests manuels

Certains aspects nécessitent une validation manuelle car ils impliquent une interaction utilisateur.

---

### Checklist Device Flow complet

Cochez chaque étape au fur et à mesure :

```
☐ 1. Démarrer Keycloak, WebApp et Device-app
☐ 2. Aller sur https://localhost:4000
☐ 3. Cliquer "🚀 Démarrer l'authentification"
☐ 4. Vérifier que le code s'affiche (ex: WDJB-MJHT)
☐ 5. Vérifier que l'URL affichée est https://localhost:3000/activate
☐ 6. Vérifier que le QR code s'affiche
☐ 7. Scanner le QR code OU aller sur /activate manuellement
☐ 8. Vérifier que le code est pré-rempli (si QR scanné)
☐ 9. Cliquer "🚀 Activer l'appareil"
☐ 10. Vérifier redirection vers Keycloak
☐ 11. Vérifier que le code est pré-rempli sur Keycloak
☐ 12. Cliquer "Continue" sur Keycloak
☐ 13. Se connecter (si pas déjà connecté)
☐ 14. Cliquer "Oui" pour approuver le device
☐ 15. Retourner sur device-app
☐ 16. Vérifier "✅ Appareil connecté avec succès !"
☐ 17. Vérifier que l'email utilisateur s'affiche
☐ 18. Aller sur https://localhost:3000/devices
☐ 19. Se connecter sur webapp
☐ 20. Vérifier que le device apparaît dans la liste
☐ 21. Vérifier les informations affichées (IP, dates, client)
```

**Si toutes les étapes passent : ✅ Le Device Flow fonctionne correctement !**

---

## 📝 Scénarios de test

### Scénario 1: Premier device

**Objectif :** Tester le flow complet pour un nouvel appareil

1. Créer un nouvel utilisateur dans Keycloak
2. Démarrer Device Flow sur device-app
3. Activer via webapp /activate
4. Vérifier que le device apparaît dans /devices

**Résultat attendu :**
- ✅ Device authentifié
- ✅ Device visible dans webapp
- ✅ Dates correctes (pas 1970)
- ✅ Seulement "Device Application" affiché (pas "WebApp Client")

---

### Scénario 2: Multiple devices

**Objectif :** Tester la gestion de plusieurs devices

1. Authentifier un premier device avec user A
2. Authentifier un deuxième device avec user A
3. Aller sur webapp /devices avec user A

**Résultat attendu :**
- ✅ Les 2 devices apparaissent dans la liste
- ✅ Chaque device a son propre Session ID
- ✅ Les IP peuvent être identiques (localhost)

---

### Scénario 3: Expiration du code

**Objectif :** Tester l'expiration du code device

1. Démarrer Device Flow
2. Noter le code et le temps d'expiration
3. Attendre l'expiration (généralement 600 secondes = 10 minutes)
4. Essayer d'activer le code expiré

**Résultat attendu :**
- ✅ Keycloak affiche "Code expired"
- ✅ Device-app arrête le polling
- ✅ Device-app revient à l'état initial

---

### Scénario 4: Code invalide

**Objectif :** Tester la gestion des codes invalides

1. Aller sur webapp /activate
2. Entrer un code inexistant (ex: AAAA-BBBB)
3. Cliquer "Activer l'appareil"

**Résultat attendu :**
- ✅ Redirection vers Keycloak
- ✅ Keycloak affiche "Invalid user code"
- ✅ Pas de device authentifié

---

### Scénario 5: Déconnexion

**Objectif :** Tester la déconnexion d'un device

1. Authentifier un device
2. Cliquer "🚪 Déconnexion" sur device-app
3. Rafraîchir la page webapp /devices

**Résultat attendu :**
- ✅ Device-app revient à l'état initial
- ✅ Session Keycloak peut rester (SSO)
- ✅ Device peut se ré-authentifier

**Note :** La session Keycloak persiste car c'est du SSO. Pour supprimer complètement, il faut :
- Soit logout sur webapp également
- Soit révoquer la session depuis Keycloak Admin

---

## ✅ Checklist complète

### Démarrage

```
☐ Keycloak lancé et accessible (http://localhost:8080)
☐ Realm "projetcis" importé
☐ Client "webapp" configuré
☐ Client "devicecis" configuré
☐ Device-app lancée (https://localhost:4000)
☐ WebApp lancée (https://localhost:3000)
```

### Tests automatisés

```
☐ ./tests/test-flow.sh passe (100%)
☐ node tests/test-integration.js passe (100%)
```

### Tests fonctionnels

```
☐ Device Flow complet fonctionne
☐ Page /activate affiche correctement
☐ QR code fonctionne (pré-remplissage)
☐ Redirection vers Keycloak fonctionne
☐ Code pré-rempli sur Keycloak
☐ Device s'authentifie avec succès
☐ WebApp liste les devices
☐ Dates affichées sont correctes
☐ Seulement devicecis affiché
```

### Architecture

```
☐ /api/status retourne 404
☐ WebApp n'appelle pas device-app directement
☐ WebApp appelle Keycloak Account API
☐ Device-app n'a pas de CORS vers webapp
☐ Keycloak est la source unique de vérité
```

---

## 🔧 Dépannage

### Tests échouent : "Service non accessible"

**Problème :** `❌ Keycloak/WebApp/Device-app non accessible`

**Solutions :**
```bash
# Vérifier que les services tournent
curl http://localhost:8080/health/ready  # Keycloak
curl https://localhost:4000/health        # Device-app
curl -k https://localhost:3000/          # WebApp

# Vérifier les ports
netstat -tuln | grep -E '8080|3000|4000'

# Relancer les services si nécessaire
```

---

### Test échoue : "/api/status ne retourne pas 404"

**Problème :** `/api/status` existe encore

**Solution :**
```bash
# Vérifier le code source
grep -n "/api/status" device-app/server.js

# Si la route existe, elle doit être supprimée
# Voir commit: 24f4d85
```

---

### Device Flow échoue : "Code non généré"

**Problème :** Device ne reçoit pas de code de Keycloak

**Solutions :**
```bash
# 1. Vérifier la configuration Keycloak
# Aller sur http://localhost:8080/admin
# Realm: projetcis → Clients → devicecis
# Vérifier: "OAuth 2.0 Device Authorization Grant Enabled" = ON

# 2. Vérifier les logs device-app
# Chercher: "❌ Erreur lors du démarrage du Device Flow"

# 3. Tester manuellement
curl -X POST http:/localhost:8080/realms/projetcis/protocol/openid-connect/auth/device \
  -d "client_id=devicecis" \
  -d "scope=openid profile email"
```

---

### WebApp : "Erreur Keycloak Account API"

**Problème :** WebApp ne peut pas récupérer les devices

**Solutions :**
```bash
# 1. Vérifier que l'utilisateur est connecté sur webapp
# → /profile doit afficher les infos user

# 2. Vérifier les logs webapp
# Chercher: "⚠️ Erreur Keycloak Account API"

# 3. Tester l'API manuellement
# Récupérer le token de la session (voir DevTools → Application → Cookies)
# Puis:
curl -H "Authorization: Bearer <TOKEN>" \
  http:/localhost:8080/realms/projetcis/account/sessions/devices
```

---

### Dates affichent "1970"

**Problème :** Timestamps non convertis

**Solution :**
```javascript
// Vérifier dans devices.ejs (ligne ~65)
// Doit être: new Date(session.started * 1000)
// PAS: new Date(session.started)

// Commit qui corrige: 6b94a4f
```

---

## 📊 Critères de succès

L'application est considérée comme fonctionnelle si :

1. ✅ **Tests automatisés passent à 100%**
   - `test-flow.sh` → 0 échecs
   - `test-integration.js` → 0 échecs

2. ✅ **Device Flow complet fonctionne**
   - Device obtient un code
   - User active sur webapp
   - Device s'authentifie
   - Device apparaît dans webapp

3. ✅ **Architecture correcte**
   - Pas de communication directe webapp ↔ device
   - Keycloak est la source unique de vérité
   - Conforme RFC 8628

4. ✅ **UX satisfaisante**
   - Page /activate fonctionnelle
   - QR code fonctionne
   - Dates correctes
   - UI lisible

---

## 📚 Ressources

- [RFC 8628 - OAuth 2.0 Device Authorization Grant](https://www.rfc-editor.org/rfc/rfc8628)
- [Keycloak Device Flow Documentation](https://www.keycloak.org/docs/latest/securing_apps/#_oauth2_device_authorization_grant)
- [Architecture Fix Documentation](./ARCHITECTURE_FIX.md)

---

**Auteur :** Tests créés pour le projet CIS OAuth2 Device Flow
**Date :** 2024
**Version :** 1.0
