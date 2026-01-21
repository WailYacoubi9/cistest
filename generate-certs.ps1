# Script PowerShell pour générer les certificats SSL/TLS pour le développement local
# Utilise mkcert (recommandé) ou openssl comme alternative

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Génération des certificats SSL/TLS" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# Obtenir le répertoire du script et se positionner à la racine du projet
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir

Write-Host "Répertoire du projet: $ScriptDir" -ForegroundColor Cyan
Write-Host ""

# Fonction pour créer les dossiers
function Create-CertDirs {
    Write-Host "Création des dossiers pour les certificats..."
    $webappCertsPath = Join-Path $ScriptDir "webapp2\certs"
    $deviceCertsPath = Join-Path $ScriptDir "device-app\certs"

    New-Item -ItemType Directory -Force -Path $webappCertsPath | Out-Null
    New-Item -ItemType Directory -Force -Path $deviceCertsPath | Out-Null
    Write-Host "✓ Dossiers créés" -ForegroundColor Green
    Write-Host ""
}

# Fonction pour générer avec mkcert (recommandé)
function Generate-WithMkcert {
    Write-Host "=== Méthode 1: Avec mkcert (recommandé) ===" -ForegroundColor Yellow
    Write-Host ""

    # Vérifier si mkcert est installé
    $mkcert = Get-Command mkcert -ErrorAction SilentlyContinue
    if (-not $mkcert) {
        Write-Host "❌ mkcert n'est pas installé." -ForegroundColor Red
        Write-Host ""
        Write-Host "Pour installer mkcert sur Windows:" -ForegroundColor Yellow
        Write-Host "  - Avec Chocolatey: choco install mkcert"
        Write-Host "  - Avec Scoop: scoop install mkcert"
        Write-Host "  - Téléchargement direct: https://github.com/FiloSottile/mkcert/releases"
        Write-Host ""
        return $false
    }

    Write-Host "✓ mkcert trouvé" -ForegroundColor Green
    Write-Host ""

    # Installer la CA locale
    Write-Host "Installation de l'autorité de certification locale..."
    & mkcert -install
    Write-Host ""

    # Générer les certificats pour webapp2
    Write-Host "Génération des certificats pour webapp2..."
    $webappCertsPath = Join-Path $ScriptDir "webapp2\certs"
    Push-Location $webappCertsPath
    & mkcert localhost 127.0.0.1 ::1
    Pop-Location
    Write-Host "✓ Certificats webapp2 générés" -ForegroundColor Green
    Write-Host ""

    # Copier les certificats pour device-app
    Write-Host "Copie des certificats pour device-app..."
    $webappCertFile = Join-Path $ScriptDir "webapp2\certs\localhost+2.pem"
    $webappKeyFile = Join-Path $ScriptDir "webapp2\certs\localhost+2-key.pem"
    $deviceCertsPath = Join-Path $ScriptDir "device-app\certs"

    Copy-Item $webappCertFile $deviceCertsPath
    Copy-Item $webappKeyFile $deviceCertsPath
    Write-Host "✓ Certificats device-app copiés" -ForegroundColor Green
    Write-Host ""

    return $true
}

# Fonction pour générer avec openssl (alternative)
function Generate-WithOpenssl {
    Write-Host "=== Méthode 2: Avec OpenSSL ===" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "⚠️  Note: Les certificats OpenSSL généreront des avertissements de sécurité" -ForegroundColor Yellow
    Write-Host "           dans le navigateur. Vous devrez les accepter manuellement."
    Write-Host ""

    # Vérifier si openssl est installé
    $openssl = Get-Command openssl -ErrorAction SilentlyContinue
    if (-not $openssl) {
        Write-Host "❌ openssl n'est pas installé." -ForegroundColor Red
        Write-Host ""
        Write-Host "OpenSSL peut être installé avec Git for Windows" -ForegroundColor Yellow
        Write-Host "ou téléchargé depuis: https://slproweb.com/products/Win32OpenSSL.html"
        Write-Host ""
        return $false
    }

    Write-Host "✓ openssl trouvé" -ForegroundColor Green
    Write-Host ""

    # Générer les certificats
    Write-Host "Génération des certificats..."

    $webappKeyFile = Join-Path $ScriptDir "webapp2\certs\localhost+2-key.pem"
    $webappCertFile = Join-Path $ScriptDir "webapp2\certs\localhost+2.pem"

    & openssl req -x509 -newkey rsa:4096 `
        -keyout $webappKeyFile `
        -out $webappCertFile `
        -days 365 -nodes `
        -subj "/CN=localhost" `
        -addext "subjectAltName=DNS:localhost,IP:127.0.0.1"

    Write-Host "✓ Certificats webapp2 générés" -ForegroundColor Green
    Write-Host ""

    # Copier pour device-app
    Write-Host "Copie des certificats pour device-app..."
    $deviceCertsPath = Join-Path $ScriptDir "device-app\certs"

    Copy-Item $webappCertFile $deviceCertsPath
    Copy-Item $webappKeyFile $deviceCertsPath
    Write-Host "✓ Certificats device-app copiés" -ForegroundColor Green
    Write-Host ""

    return $true
}

# Main
try {
    Create-CertDirs

    # Essayer d'abord avec mkcert
    if (Generate-WithMkcert) {
        Write-Host "=========================================" -ForegroundColor Green
        Write-Host "✅ Certificats générés avec succès!" -ForegroundColor Green
        Write-Host "=========================================" -ForegroundColor Green
        Write-Host ""
        Write-Host "Les certificats sont installés dans:" -ForegroundColor Cyan
        Write-Host "  - webapp2\certs\"
        Write-Host "  - device-app\certs\"
        Write-Host ""
        Write-Host "Avec mkcert, les certificats sont automatiquement" -ForegroundColor Green
        Write-Host "approuvés par votre système. Pas d'avertissement!"
        Write-Host ""
        Write-Host "Vous pouvez maintenant démarrer le projet:" -ForegroundColor Yellow
        Write-Host "  docker-compose up -d --build"
        Write-Host ""
        exit 0
    }

    # Sinon, essayer avec openssl
    Write-Host "mkcert non disponible, tentative avec openssl..."
    Write-Host ""

    if (Generate-WithOpenssl) {
        Write-Host "=========================================" -ForegroundColor Green
        Write-Host "✅ Certificats générés avec succès!" -ForegroundColor Green
        Write-Host "=========================================" -ForegroundColor Green
        Write-Host ""
        Write-Host "Les certificats sont installés dans:" -ForegroundColor Cyan
        Write-Host "  - webapp2\certs\"
        Write-Host "  - device-app\certs\"
        Write-Host ""
        Write-Host "⚠️  IMPORTANT: Les certificats OpenSSL nécessitent" -ForegroundColor Yellow
        Write-Host "   une acceptation manuelle dans le navigateur:"
        Write-Host ""
        Write-Host "   1. Allez sur https://localhost:3000"
        Write-Host "   2. Cliquez sur 'Avancé' ou 'Advanced'"
        Write-Host "   3. Cliquez sur 'Continuer vers localhost (dangereux)'"
        Write-Host ""
        Write-Host "Vous pouvez maintenant démarrer le projet:" -ForegroundColor Yellow
        Write-Host "  docker-compose up -d --build"
        Write-Host ""
        exit 0
    }

    # Si rien ne fonctionne
    Write-Host "=========================================" -ForegroundColor Red
    Write-Host "❌ Impossible de générer les certificats" -ForegroundColor Red
    Write-Host "=========================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "Ni mkcert ni openssl ne sont disponibles." -ForegroundColor Yellow
    Write-Host "Veuillez installer l'un d'eux et réessayer."
    Write-Host ""
    Write-Host "Recommandation: Installez mkcert avec Chocolatey:" -ForegroundColor Cyan
    Write-Host "  choco install mkcert"
    Write-Host ""
    exit 1

} catch {
    Write-Host "❌ Erreur lors de la génération des certificats:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}
