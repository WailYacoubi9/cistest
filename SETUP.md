# Guide de Configuration du Projet

## Prérequis

- Docker et Docker Compose
- Git
- **mkcert** (recommandé) ou **OpenSSL** pour les certificats SSL

## Installation Rapide

### Étape 1: Cloner le projet

```bash
git clone https://github.com/WailYacoubi9/cistest.git
cd cistest
git checkout claude/fix-connection-error-w1svV
```

### Étape 2: Générer les certificats SSL

Les certificats sont **obligatoires** pour que l'application fonctionne en HTTPS.

#### Sur Windows (PowerShell):

```powershell
.\generate-certs.ps1
```

#### Sur Linux/Mac/Git Bash:

```bash
chmod +x generate-certs.sh
./generate-certs.sh
```

#### Installation de mkcert (recommandé)

**Windows (Chocolatey):**
```powershell
choco install mkcert
```

**Windows (Scoop):**
```powershell
scoop install mkcert
```

**macOS:**
```bash
brew install mkcert
```

**Linux:**
```bash
# Debian/Ubuntu
curl -JLO "https://dl.filippo.io/mkcert/latest?for=linux/amd64"
chmod +x mkcert-v*-linux-amd64
sudo cp mkcert-v*-linux-amd64 /usr/local/bin/mkcert

# Arch Linux
sudo pacman -S mkcert
```

### Étape 3: Démarrer le projet

```bash
# Démarrer tous les services
docker-compose up -d --build

# Suivre les logs
docker-compose logs -f
```

### Étape 4: Accéder aux applications

Attendez que les logs montrent "Serveur HTTPS démarré" (30-60 secondes), puis:

- **Webapp**: https://localhost:3000
- **Device App**: http://localhost:4000 (ou https://localhost:4000)
- **Keycloak Admin**: http://localhost:8080 (admin/admin)

## Structure des Certificats

Les certificats doivent être placés dans:

```
webapp2/
  └── certs/
      ├── localhost+2.pem          # Certificat public
      └── localhost+2-key.pem      # Clé privée

device-app/
  └── certs/
      ├── localhost+2.pem          # Certificat public
      └── localhost+2-key.pem      # Clé privée
```

## Démarrage Complet

Voici toutes les commandes à exécuter dans un nouveau dossier:

```bash
# 1. Cloner et se positionner
git clone https://github.com/WailYacoubi9/cistest.git
cd cistest
git checkout claude/fix-connection-error-w1svV

# 2. Générer les certificats
# Windows PowerShell:
.\generate-certs.ps1
# OU Linux/Mac:
./generate-certs.sh

# 3. Démarrer le projet
docker-compose up -d --build

# 4. Suivre les logs (optionnel)
docker-compose logs -f
```

## Séquence de Démarrage

1. **PostgreSQL** démarre (5 secondes)
2. **Keycloak** démarre et importe le realm (30-60 secondes)
3. **Webapp** se connecte à Keycloak avec retry automatique
4. **Device-app** démarre

Vous verrez des messages de retry pendant que Keycloak initialise - c'est normal!

```
Tentative 1/10 échouée. Nouvelle tentative dans 2000ms...
Tentative 2/10 échouée. Nouvelle tentative dans 3000ms...
...
Issuer découvert: http://localhost:8080/realms/projetcis
Client OpenID Connect initialisé
Serveur HTTPS démarré
```

## Commandes Utiles

```bash
# Arrêter tous les services
docker-compose down

# Arrêter et supprimer les volumes (fresh start)
docker-compose down -v

# Reconstruire et redémarrer
docker-compose up -d --build

# Voir les logs
docker-compose logs -f

# Voir les logs d'un service spécifique
docker-compose logs -f webapp
docker-compose logs -f keycloak

# Vérifier le statut
docker-compose ps

# Redémarrer un service
docker-compose restart webapp
```

## Problèmes Courants

### "Cannot read property of null" ou erreur de certificats

**Solution:** Générez les certificats avec `./generate-certs.ps1` (Windows) ou `./generate-certs.sh` (Linux/Mac)

### "ECONNREFUSED" au démarrage

**Normal!** L'application retry automatiquement pendant que Keycloak démarre. Attendez 30-60 secondes.

### "unauthorized_client" ou "Invalid client credentials"

**Cause:** Keycloak a de vieilles données

**Solution:**
```bash
docker-compose down
docker volume rm equipe1_keycloak-postgres
docker-compose up -d --build
```

### Port 3000 ou 4000 déjà utilisé

**Vérifier:**
```bash
# Windows
netstat -ano | findstr :3000
netstat -ano | findstr :4000

# Linux/Mac
lsof -i :3000
lsof -i :4000
```

**Solution:** Arrêtez le processus qui utilise le port ou changez le port dans `docker-compose.yml`

### Le navigateur affiche "Connexion non sécurisée"

**Avec mkcert:** Ne devrait pas arriver, les certificats sont approuvés automatiquement

**Avec OpenSSL:**
1. Cliquez sur "Avancé" ou "Advanced"
2. Cliquez sur "Continuer vers localhost (dangereux)"

## Architecture du Projet

```
cistest/
├── webapp2/              # Application web principale (HTTPS - port 3000)
│   ├── certs/           # Certificats SSL (à générer)
│   ├── config/          # Configuration Keycloak
│   ├── routes/          # Routes Express
│   └── server.js        # Serveur HTTPS
│
├── device-app/          # Application device flow (HTTP/HTTPS - port 4000)
│   ├── certs/           # Certificats SSL (à générer)
│   └── server.js        # Serveur HTTP/HTTPS
│
├── docker-compose.yml   # Configuration Docker
└── generate-certs.*     # Scripts de génération de certificats
```

## Fichiers de Documentation

- **SETUP.md** (ce fichier) - Guide de configuration initial
- **TROUBLESHOOTING.md** - Guide de dépannage pour webapp
- **DEVICE_APP_TROUBLESHOOTING.md** - Guide de dépannage pour device-app
- **FIX_SUMMARY.md** - Résumé des corrections appliquées

## Support

Si vous rencontrez des problèmes:

1. Consultez **TROUBLESHOOTING.md**
2. Vérifiez les logs: `docker-compose logs -f`
3. Faites un fresh start: `docker-compose down -v && docker-compose up -d --build`
