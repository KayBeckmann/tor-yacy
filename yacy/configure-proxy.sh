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

set_config() {
    local key="$1"
    local value="$2"

    if grep -q "^${key}=" "$YACY_CONF" 2>/dev/null; then
        sed -i "s|^${key}=.*|${key}=${value}|" "$YACY_CONF"
    else
        echo "${key}=${value}" >> "$YACY_CONF"
    fi
}

# Warte bis yacy.conf existiert und konfiguriere alles
configure_yacy() {
    local attempts=0
    while [ ! -f "$YACY_CONF" ] && [ $attempts -lt 60 ]; do
        sleep 2
        attempts=$((attempts + 1))
    done

    if [ ! -f "$YACY_CONF" ]; then
        echo "WARNUNG: yacy.conf nicht gefunden nach 120s"
        return
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
    ONION_FILE="/opt/yacy_search_server/DATA/SETTINGS/onion_address"
    if [ -f "/hidden_service/hostname" ]; then
        ONION_ADDR=$(cat /hidden_service/hostname | tr -d '[:space:]')
        echo "Eigene Onion-Adresse: $ONION_ADDR"
        # YaCy mitteilen unter welcher Adresse dieser Knoten erreichbar ist
        set_config "serverhost" "$ONION_ADDR"
        set_config "serverport" "$PEER_PORT"
        echo "$ONION_ADDR" > "$ONION_FILE"
    fi

    # Bootstrap-Peer konfigurieren
    if [ -n "$BOOTSTRAP_PEER" ]; then
        echo "Konfiguriere Bootstrap-Peer: $BOOTSTRAP_PEER"
        # Seed-Liste vom Bootstrap-Peer laden
        SEED_URL="http://${BOOTSTRAP_PEER}:${PEER_PORT}/yacy/seedlist.json"
        set_config "network.unit.bootstrap.seedlist0" "$SEED_URL"
        set_config "network.unit.bootstrap.seedlistcount" "1"
        echo "Bootstrap-Peer konfiguriert: $SEED_URL"
    fi

    # P2P-Modus aktivieren
    set_config "network.unit.dht" "true"
    set_config "network.unit.dhtredundancy.junior" "1"
    set_config "network.unit.dhtredundancy.senior" "3"

    echo "YaCy Peering-Konfiguration abgeschlossen."
}

# Konfiguration im Hintergrund ausfuehren (YaCy muss erst starten)
configure_yacy &

# YaCy starten
cd /opt/yacy_search_server
exec sh /opt/yacy_search_server/startYACY.sh -f
