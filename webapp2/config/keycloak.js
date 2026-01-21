require('dotenv').config();
const { Issuer } = require('openid-client');

/**
 * Wait for a specified amount of time
 * @param {number} ms - milliseconds to wait
 */
function sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}

/**
 * Retry logic with exponential backoff
 * @param {Function} fn - async function to retry
 * @param {number} maxRetries - maximum number of retries
 * @param {number} initialDelay - initial delay in milliseconds
 */
async function retryWithBackoff(fn, maxRetries = 10, initialDelay = 1000) {
    let lastError;

    for (let attempt = 1; attempt <= maxRetries; attempt++) {
        try {
            return await fn();
        } catch (error) {
            lastError = error;

            if (attempt === maxRetries) {
                throw error;
            }

            const delay = initialDelay * Math.pow(1.5, attempt - 1);
            console.log(`Tentative ${attempt}/${maxRetries} échouée. Nouvelle tentative dans ${Math.round(delay)}ms...`);
            console.log(`Erreur: ${error.message}`);

            await sleep(delay);
        }
    }

    throw lastError;
}

async function initializeKeycloak() {
    try {
        // UTILISER KEYCLOAK_INTERNAL_URL pour la découverte depuis Docker
        const keycloakInternalUrl = process.env.KEYCLOAK_INTERNAL_URL || process.env.KEYCLOAK_URL || 'http://localhost:8080';
        const keycloakPublicUrl = process.env.KEYCLOAK_URL || 'http://localhost:8080';
        const realm = process.env.REALM;
        const clientId = process.env.CLIENT_ID;
        const clientSecret = process.env.CLIENT_SECRET;
        const redirectUri = process.env.REDIRECT_URI;

        if (!realm || !clientId || !redirectUri) {
            throw new Error("Configuration Keycloak manquante dans .env");
        }

        const issuerUrl = `${keycloakInternalUrl}/realms/${realm}`;
        console.log('Découverte de l\'issuer:', issuerUrl);

        // Discover depuis l'URL interne (keycloak:8080) avec retry
        const issuer = await retryWithBackoff(
            async () => await Issuer.discover(issuerUrl),
            10,
            2000
        );
        console.log('Issuer découvert:', issuer.metadata.issuer);

        // Correction des endpoints pour utiliser l'URL interne pour les appels serveur-à-serveur
        // mais garder l'URL publique pour les redirections navigateur
        const correctedMetadata = {
            ...issuer.metadata,
            // Endpoints serveur-à-serveur (utiliser URL interne Docker)
            token_endpoint: issuer.metadata.token_endpoint.replace(keycloakPublicUrl, keycloakInternalUrl),
            userinfo_endpoint: issuer.metadata.userinfo_endpoint.replace(keycloakPublicUrl, keycloakInternalUrl),
            revocation_endpoint: issuer.metadata.revocation_endpoint?.replace(keycloakPublicUrl, keycloakInternalUrl),
            introspection_endpoint: issuer.metadata.introspection_endpoint?.replace(keycloakPublicUrl, keycloakInternalUrl),
            jwks_uri: issuer.metadata.jwks_uri?.replace(keycloakPublicUrl, keycloakInternalUrl),
            // Endpoints pour redirections navigateur (garder URL publique)
            authorization_endpoint: issuer.metadata.authorization_endpoint,
            end_session_endpoint: issuer.metadata.end_session_endpoint, // Logout = redirect navigateur
            registration_endpoint: issuer.metadata.registration_endpoint
        };

        console.log('Endpoints corrigés:');
        console.log('   - Token endpoint:', correctedMetadata.token_endpoint);
        console.log('   - Userinfo endpoint:', correctedMetadata.userinfo_endpoint);
        console.log('   - Authorization endpoint:', correctedMetadata.authorization_endpoint);

        // Créer un nouvel Issuer avec les métadonnées corrigées
        const correctedIssuer = new Issuer(correctedMetadata);

        const keycloakClient = new correctedIssuer.Client({
            client_id: clientId,
            client_secret: clientSecret,
            redirect_uris: [redirectUri],
            response_types: ['code']
        });

        console.log('Client OpenID Connect initialisé');
        console.log('Configuration:');
        console.log('   - URL interne:', keycloakInternalUrl);
        console.log('   - URL publique:', keycloakPublicUrl);
        console.log('   - Client ID:', clientId);
        console.log('   - Redirect URI:', redirectUri);
        console.log('');

        return keycloakClient;
    } catch (error) {
        console.error("Erreur lors de l'initialisation de Keycloak:", error);
        throw error;
    }
}

module.exports = {
    initializeKeycloak
};