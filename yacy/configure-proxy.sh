#!/bin/bash
set -e

DATA_DIR="/opt/yacy_search_server/DATA"
SETTINGS_DIR="$DATA_DIR/SETTINGS"
YACY_CONF="$SETTINGS_DIR/yacy.conf"

PROXY_HOST="${YACY_PROXY_HOST:-}"
PROXY_PORT="${YACY_PROXY_PORT:-9050}"
BOOTSTRAP_PEER="${BOOTSTRAP_PEER:-}"
NETWORK_NAME="${NETWORK_NAME:-tor}"
PEER_PORT="${PEER_PORT:-8090}"
ADMIN_USER="${YACY_ADMIN_USER:-admin}"
ADMIN_PASSWORD="${YACY_ADMIN_PASSWORD:-}"

set_config() {
    local key="$1"
    local value="$2"

    if grep -q "^${key}=" "$YACY_CONF" 2>/dev/null; then
        sed -i "s|^${key}=.*|${key}=${value}|" "$YACY_CONF"
    else
        echo "${key}=${value}" >> "$YACY_CONF"
    fi
}

# SETTINGS-Verzeichnis und yacy.conf erstellen falls nicht vorhanden
mkdir -p "$SETTINGS_DIR"
if [ ! -f "$YACY_CONF" ]; then
    echo "Erstelle initiale yacy.conf..."
    touch "$YACY_CONF"
fi

# Proxy-Einstellungen fuer Tor
if [ -n "$PROXY_HOST" ]; then
    echo "Konfiguriere Tor-Proxy: $PROXY_HOST:$PROXY_PORT"
    set_config "remoteProxyUse" "true"
    set_config "remoteProxyHost" "$PROXY_HOST"
    set_config "remoteProxyPort" "$PROXY_PORT"
    set_config "remoteProxyUse4SSL" "true"
    set_config "remoteProxyNoProxy" ""
    echo "Tor-Proxy konfiguriert."
fi

# Netzwerk-Name setzen (eigenes Tor-Netzwerk)
echo "Setze Netzwerk-Name: $NETWORK_NAME"
set_config "network.unit.name" "$NETWORK_NAME"

# Eigene .onion-Adresse als Peer-Adresse setzen
if [ -f "/hidden_service/hostname" ]; then
    ONION_ADDR=$(cat /hidden_service/hostname | tr -d '[:space:]')
    echo "Eigene Onion-Adresse: $ONION_ADDR"
    set_config "serverhost" "$ONION_ADDR"
    set_config "serverport" "$PEER_PORT"
fi

# Bootstrap-Peer konfigurieren
if [ -n "$BOOTSTRAP_PEER" ]; then
    echo "Konfiguriere Bootstrap-Peer: $BOOTSTRAP_PEER"
    SEED_URL="http://${BOOTSTRAP_PEER}:${PEER_PORT}/yacy/seedlist.json"
    set_config "network.unit.bootstrap.seedlist0" "$SEED_URL"
    set_config "network.unit.bootstrap.seedlistcount" "1"
    echo "Bootstrap-Peer konfiguriert: $SEED_URL"
fi

# P2P-Modus aktivieren
set_config "network.unit.dht" "true"
set_config "network.unit.dhtredundancy.junior" "1"
set_config "network.unit.dhtredundancy.senior" "3"

# Admin-Zugangsdaten setzen
if [ -n "$ADMIN_PASSWORD" ]; then
    echo "Konfiguriere Admin-Zugang: $ADMIN_USER"
    # YaCy verwendet HTTP Digest Auth: MD5(username:realm:password)
    ADMIN_REALM="The YaCy access is limited to administrators. If you don't know the password, you can change it using <yacy-home>/bin/passwd.sh <new-password>"
    ADMIN_HASH="MD5:$(echo -n "${ADMIN_USER}:${ADMIN_REALM}:${ADMIN_PASSWORD}" | md5sum | awk '{print $1}')"
    set_config "adminAccountUserName" "$ADMIN_USER"
    set_config "adminAccountBase64MD5" "$ADMIN_HASH"
    set_config "adminRealm" "$ADMIN_REALM"
    set_config "adminAccountForLocalhost" "false"
    echo "Admin-Zugang konfiguriert."
else
    echo "WARNUNG: Kein Admin-Passwort gesetzt. Admin-Interface ist ohne Authentifizierung erreichbar!"
fi

echo "YaCy-Konfiguration abgeschlossen. Starte YaCy..."

# YaCy starten
cd /opt/yacy_search_server
exec sh /opt/yacy_search_server/startYACY.sh -f
