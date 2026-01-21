# Projet CIS – Démonstrateur OAuth2 / OpenID Connect avec Keycloak

> **🚀 NOUVEAU UTILISATEUR?** Consultez **[SETUP.md](SETUP.md)** pour un guide de démarrage rapide en 4 étapes!

Ce projet met en place une architecture complète pour illustrer l'authentification par délégation avec Keycloak :

- Une application Node.js / Express (`webapp2`) protégée par OpenID Connect (flow "code" + PKCE).
- Un serveur Keycloak (mode `start-dev`) avec import automatique d’un realm préconfiguré (`projetcis`).
- Une base PostgreSQL utilisée comme backend de Keycloak.
- Un serveur HTTPS local pour la webapp avec certificats auto-signés.

L’ensemble est orchestré avec Docker Compose.

---

## 1. Architecture générale

Organisation des dossiers (simplifiée) :

```text
cis-oidc/
├─ docker-compose.yml        # Déclaration des services Docker (Postgres, Keycloak, Webapp)
├─ webapp2/
│  ├─ server.js              # Entrée principale Node.js (Express + HTTPS)
│  ├─ config/
│  │   └─ keycloak.js        # Initialisation du client OpenID Connect
│  ├─ import/
│  │   └─ realm.json         # Realm Keycloak "projetcis"
│  ├─ routes/
│  │   ├─ auth.js            # Routes /login, /logout, /auth/callback, /register
│  │   └─ pages.js           
│  ├─ middleware/
│  │   └─ auth.js            # requireAuth, refreshTokenIfNeeded, etc.
│  ├─ views/                 # Templates EJS
│  ├─ public/                # Assets statiques
│  ├─ certs/                 # Certificats TLS locaux
│  ├─ .env                   # Variables d’environnement
│  └─ Dockerfile             # Image de la webapp
├─ scripts/
│  ├─ setup-certs.ps1        # Générer les certificats TLS
```

Services Docker principaux :

- `postgres-keycloak` : base PostgreSQL pour Keycloak (DB, utilisateur keycloak).
- `keycloak` : serveur Keycloak (import automatique du realm depuis `webapp2/imports/realm.json`).
- `cis-webapp` : application Node.js / Express exposée en HTTPS sur `https://localhost:3000`.

## Prérequis

Sur la machine hôte :

- Docker Desktop installé et fonctionnel.
- Node.js 18+ (optionnel, uniquement si on veut lancer la webapp hors Docker).
- Un outil de génération de certificats (par ex. `mkcert`) si l’on doit régénérer les certificats HTTPS locaux.

Ajouter l’entrée suivante dans le fichier hosts (`C:\Windows\System32\drivers\etc\hosts`) :

```text
127.0.0.1   keycloak
```

Cette ligne permet au navigateur d’accéder à Keycloak via `http://keycloak:8080` comme si c’était un nom de machine.

## Certificats TLS et script de génération

⚠️ **IMPORTANT:** Les certificats SSL sont **OBLIGATOIRES**. L'application ne démarrera pas sans eux!

### Génération automatique (Recommandé)

Utilisez les scripts fournis pour générer automatiquement les certificats:

**Windows PowerShell:**
```powershell
.\generate-certs.ps1
```

**Linux/Mac/Git Bash:**
```bash
./generate-certs.sh
```

Ces scripts:
- Génèrent les certificats avec `mkcert` (ou `openssl` en fallback)
- Créent les fichiers dans `webapp2/certs/` et `device-app/certs/`
- Configurent les permissions correctes
- Installent l'autorité de certification locale (avec mkcert)

### Génération manuelle

Si vous préférez générer manuellement, les fichiers attendus sont :

```text
webapp2/certs/
  ├─ localhost+2.pem
  └─ localhost+2-key.pem

device-app/certs/
  ├─ localhost+2.pem
  └─ localhost+2-key.pem
```

Avec `mkcert` :
```bash
# Installer mkcert et l'autorité de certification
mkcert -install

# Générer pour webapp2
cd webapp2/certs
mkcert localhost 127.0.0.1 ::1

# Copier pour device-app
cp localhost+2.pem ../../device-app/certs/
cp localhost+2-key.pem ../../device-app/certs/
```

Ces fichiers ne sont pas versionnés (ignorés par `.gitignore`) et doivent être générés localement.

## Variables d’environnement de la webapp

Créez `webapp2/.env` (non versionné) avec, par exemple :

```env
PORT=3000

# URLs Keycloak
KEYCLOAK_URL=http://localhost:8080
KEYCLOAK_INTERNAL_URL=http://keycloak:8080

# Client OIDC
REALM=projetcis
CLIENT_ID=webapp
CLIENT_SECRET=webapp-client-secret-123
REDIRECT_URI=https://localhost:3000/auth/callback

# Session Express
SESSION_SECRET=<Votre secret ici>
```

- `KEYCLOAK_INTERNAL_URL` : utilisée par la webapp **dans Docker** pour interroger Keycloak (`http://keycloak:8080`).
- `KEYCLOAK_URL` : utilisée par le navigateur (public) et dans les redirections (`http://localhost:8080` ou via l’entrée hosts).

## Configuration Keycloak (`realm.json`)

Le fichier `webapp2/imports/realm.json` définit le realm `projetcis` :

- Realm activé avec options de connexion (login, reset password, remember-me, etc.).
- Client `webapp` (confidentiel) avec `client-secret`.
- `redirectUris` incluant `https://localhost:3000/auth/callback` et `https://localhost:3000/*`.
- `webOrigins` incluant `https://localhost:3000`.
- PKCE activé (`"pkce.code.challenge.method": "S256"`).
- Quelques rôles de base (`user`, `admin`).

Au démarrage, Keycloak importe ce realm automatiquement grâce à l’option d’import dans `docker-compose.yml`.

## Démarrage avec Docker Compose

Depuis la racine du projet (`cis-oidc/`) :
```bash
# Générer les certificats TLS
.scripts\setup-certs.ps1
```

```bash
# Construire et lancer les services
docker compose up --build
```

Services exposés :

- Postgres sur `localhost:5432`
- Keycloak sur `http://localhost:8080`
- Webapp sur `https://localhost:3000`

Accéder à l’interface Keycloak d’administration (facultatif) :

```
http://localhost:8080
```

Identifiants admin par défaut (config d’exemple) :

```text
admin / admin
```

Accéder à la webapp :

```
https://localhost:3000
```

Cliquer sur « Se connecter » pour lancer le flux OIDC (redirection vers Keycloak, puis retour sur `/auth/callback`).

La page `/profile` affiche les informations de l’utilisateur et la durée de validité du token.

## Flux d’authentification

Résumé du flux standard (login) :

1. L’utilisateur ouvre `https://localhost:3000`.
2. Il clique sur « Se connecter ».
3. La route `GET /login` génère un `code_verifier`, un `code_challenge` et un `state`, puis redirige vers Keycloak.
4. L’utilisateur s’authentifie sur Keycloak.
5. Keycloak redirige vers `/auth/callback` avec un `code` (flow « authorization code »).
6. La webapp échange ce code contre des tokens (`access_token`, `id_token`, `refresh_token`).
7. Les informations de l’utilisateur sont récupérées via `userinfo` et stockées en session.
8. Le middleware `refreshTokenIfNeeded` peut rafraîchir automatiquement le token si nécessaire.

Un rafraîchissement automatique est déclenché lorsque le token expire.

## Nettoyage

Pour arrêter et supprimer les conteneurs :

```bash
docker compose down
```
---