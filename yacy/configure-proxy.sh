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

# Netzwerk-Definition setzen (eigene Tor-Netzwerkdatei statt freeworld)
echo "Setze Netzwerk: $NETWORK_NAME"
set_config "network.unit.definition" "defaults/yacy.network.tor.unit"
set_config "network.unit.name" "$NETWORK_NAME"
set_config "network.unit.description" "YaCy Tor Hidden Service Network"
set_config "network.unit.domain" "any"
set_config "network.unit.domain.nocheck" "true"

# Alte freeworld-Seedlisten entfernen
sed -i '/^network\.unit\.bootstrap\.seedlist[0-9]/d' "$YACY_CONF"

# Eigene .onion-Adresse als Peer-Adresse setzen
if [ -f "/hidden_service/hostname" ]; then
    ONION_ADDR=$(cat /hidden_service/hostname | tr -d '[:space:]')
    echo "Eigene Onion-Adresse: $ONION_ADDR"
    set_config "staticIP" "$ONION_ADDR"
    set_config "serverport" "$PEER_PORT"
fi

# Bootstrap-Peer konfigurieren
NETWORK_UNIT_FILE="/opt/yacy_search_server/defaults/yacy.network.tor.unit"
if [ -n "$BOOTSTRAP_PEER" ]; then
    echo "Konfiguriere Bootstrap-Peer: $BOOTSTRAP_PEER"
    SEED_URL="http://${BOOTSTRAP_PEER}:${PEER_PORT}/yacy/seedlist.html"
    # Seedlist in der Netzwerk-Definitionsdatei setzen
    if grep -q "^network.unit.bootstrap.seedlist0" "$NETWORK_UNIT_FILE" 2>/dev/null; then
        sed -i "s|^network.unit.bootstrap.seedlist0.*|network.unit.bootstrap.seedlist0 = ${SEED_URL}|" "$NETWORK_UNIT_FILE"
    else
        echo "network.unit.bootstrap.seedlist0 = ${SEED_URL}" >> "$NETWORK_UNIT_FILE"
    fi
    # Seedlist auch direkt in yacy.conf setzen (YaCy ueberschreibt network.unit.definition
    # zur Laufzeit, sodass die Network-Unit-Datei nicht mehr gelesen wird)
    set_config "network.unit.bootstrap.seedlist0" "$SEED_URL"
    echo "Bootstrap-Peer konfiguriert: $SEED_URL"
fi

# P2P-Modus aktivieren
set_config "network.unit.dht" "true"
set_config "network.unit.dhtredundancy.junior" "1"
set_config "network.unit.dhtredundancy.senior" "3"

# Bootstrap-Timeout fuer Tor erhoehen (Standard 20s ist zu kurz)
set_config "bootstrapLoadTimeout" "60000"

# Peer-Akzeptanz: Alle Peer-Typen erlauben (virgin, junior, senior, principal)
# Kritisch fuer Tor-Netzwerke, wo Erreichbarkeitstests nicht funktionieren
set_config "cluster.mode" "publiccluster"
set_config "seedUploadMethod" "none"

# Greedy Learning aktivieren fuer bessere Peer-Entdeckung
set_config "greedylearning.enabled" "true"
set_config "greedylearning.isActive" "true"
set_config "greedylearning.limit.doccount" "1000"

# Remote Search und Crawling erlauben
set_config "remotesearch.result.store" "true"
set_config "remotesearch.result.store.doSearch" "true"
set_config "crawlResponse" "true"

# Index-Austausch aktivieren
set_config "allowReceiveIndex" "true"
set_config "allowTransmitIndex" "true"

# DHT Transfer aktivieren
set_config "DHT.sendChunkLimit" "100"
set_config "DHT.receiveChunkLimit" "100"

# Peers nicht ablehnen basierend auf IP-Validierung
set_config "network.unit.access.whitelist" ""
set_config "network.unit.access.blacklist" ""

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
