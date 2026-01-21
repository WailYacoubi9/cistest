#!/bin/bash

# Script pour générer les certificats SSL/TLS pour le développement local
# Utilise mkcert (recommandé) ou openssl comme alternative

set -e

echo "========================================="
echo "Génération des certificats SSL/TLS"
echo "========================================="
echo ""

# Fonction pour créer les dossiers
create_cert_dirs() {
    echo "Création des dossiers pour les certificats..."
    mkdir -p webapp2/certs
    mkdir -p device-app/certs
    echo "✓ Dossiers créés"
    echo ""
}

# Fonction pour générer avec mkcert (recommandé)
generate_with_mkcert() {
    echo "=== Méthode 1: Avec mkcert (recommandé) ==="
    echo ""

    if ! command -v mkcert &> /dev/null; then
        echo "❌ mkcert n'est pas installé."
        echo ""
        echo "Pour installer mkcert:"
        echo "  - Windows (Chocolatey): choco install mkcert"
        echo "  - Windows (Scoop): scoop install mkcert"
        echo "  - macOS: brew install mkcert"
        echo "  - Linux: voir https://github.com/FiloSottile/mkcert#installation"
        echo ""
        return 1
    fi

    echo "✓ mkcert trouvé"
    echo ""

    # Installer la CA locale (seulement si pas déjà fait)
    echo "Installation de l'autorité de certification locale..."
    mkcert -install
    echo ""

    # Générer les certificats pour webapp2
    echo "Génération des certificats pour webapp2..."
    cd webapp2/certs
    mkcert localhost 127.0.0.1 ::1
    cd ../..
    echo "✓ Certificats webapp2 générés"
    echo ""

    # Copier les certificats pour device-app
    echo "Copie des certificats pour device-app..."
    cp webapp2/certs/localhost+2.pem device-app/certs/
    cp webapp2/certs/localhost+2-key.pem device-app/certs/
    echo "✓ Certificats device-app copiés"
    echo ""

    return 0
}

# Fonction pour générer avec openssl (alternative)
generate_with_openssl() {
    echo "=== Méthode 2: Avec OpenSSL ==="
    echo ""
    echo "⚠️  Note: Les certificats OpenSSL généreront des avertissements de sécurité"
    echo "           dans le navigateur. Vous devrez les accepter manuellement."
    echo ""

    if ! command -v openssl &> /dev/null; then
        echo "❌ openssl n'est pas installé."
        return 1
    fi

    echo "✓ openssl trouvé"
    echo ""

    # Générer les certificats
    echo "Génération des certificats..."
    openssl req -x509 -newkey rsa:4096 -keyout webapp2/certs/localhost+2-key.pem \
        -out webapp2/certs/localhost+2.pem -days 365 -nodes \
        -subj "/CN=localhost" \
        -addext "subjectAltName=DNS:localhost,IP:127.0.0.1"

    echo "✓ Certificats webapp2 générés"
    echo ""

    # Copier pour device-app
    echo "Copie des certificats pour device-app..."
    cp webapp2/certs/localhost+2.pem device-app/certs/
    cp webapp2/certs/localhost+2-key.pem device-app/certs/
    echo "✓ Certificats device-app copiés"
    echo ""

    return 0
}

# Vérifier les permissions
set_permissions() {
    echo "Configuration des permissions..."
    chmod 600 webapp2/certs/localhost+2-key.pem
    chmod 644 webapp2/certs/localhost+2.pem
    chmod 600 device-app/certs/localhost+2-key.pem
    chmod 644 device-app/certs/localhost+2.pem
    echo "✓ Permissions configurées"
    echo ""
}

# Main
main() {
    create_cert_dirs

    # Essayer d'abord avec mkcert
    if generate_with_mkcert; then
        set_permissions
        echo "========================================="
        echo "✅ Certificats générés avec succès!"
        echo "========================================="
        echo ""
        echo "Les certificats sont installés dans:"
        echo "  - webapp2/certs/"
        echo "  - device-app/certs/"
        echo ""
        echo "Avec mkcert, les certificats sont automatiquement"
        echo "approuvés par votre système. Pas d'avertissement!"
        echo ""
        echo "Vous pouvez maintenant démarrer le projet:"
        echo "  docker-compose up -d --build"
        echo ""
        return 0
    fi

    # Sinon, essayer avec openssl
    echo "mkcert non disponible, tentative avec openssl..."
    echo ""

    if generate_with_openssl; then
        set_permissions
        echo "========================================="
        echo "✅ Certificats générés avec succès!"
        echo "========================================="
        echo ""
        echo "Les certificats sont installés dans:"
        echo "  - webapp2/certs/"
        echo "  - device-app/certs/"
        echo ""
        echo "⚠️  IMPORTANT: Les certificats OpenSSL nécessitent"
        echo "   une acceptation manuelle dans le navigateur:"
        echo ""
        echo "   1. Allez sur https://localhost:3000"
        echo "   2. Cliquez sur 'Avancé' ou 'Advanced'"
        echo "   3. Cliquez sur 'Continuer vers localhost (dangereux)'"
        echo ""
        echo "Vous pouvez maintenant démarrer le projet:"
        echo "  docker-compose up -d --build"
        echo ""
        return 0
    fi

    # Si rien ne fonctionne
    echo "========================================="
    echo "❌ Impossible de générer les certificats"
    echo "========================================="
    echo ""
    echo "Ni mkcert ni openssl ne sont disponibles."
    echo "Veuillez installer l'un d'eux et réessayer."
    echo ""
    return 1
}

main
