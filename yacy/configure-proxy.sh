#!/bin/bash
set -e

DATA_DIR="/opt/yacy_search_server/DATA"
SETTINGS_DIR="$DATA_DIR/SETTINGS"
YACY_CONF="$SETTINGS_DIR/yacy.conf"

PROXY_HOST="${YACY_PROXY_HOST:-}"
PROXY_PORT="${YACY_PROXY_PORT:-9050}"

# Warte bis DATA-Verzeichnis existiert und konfiguriere Proxy
configure_proxy() {
    # Warte auf yacy.conf (wird beim ersten Start erstellt)
    local attempts=0
    while [ ! -f "$YACY_CONF" ] && [ $attempts -lt 60 ]; do
        sleep 2
        attempts=$((attempts + 1))
    done

    if [ -f "$YACY_CONF" ] && [ -n "$PROXY_HOST" ]; then
        echo "Konfiguriere Tor-Proxy: $PROXY_HOST:$PROXY_PORT"

        # Proxy-Einstellungen in yacy.conf setzen
        set_config "remoteProxyUse" "true"
        set_config "remoteProxyHost" "$PROXY_HOST"
        set_config "remoteProxyPort" "$PROXY_PORT"
        set_config "remoteProxyUse4SSL" "true"

        echo "Tor-Proxy konfiguriert."
    fi
}

set_config() {
    local key="$1"
    local value="$2"

    if grep -q "^${key}=" "$YACY_CONF" 2>/dev/null; then
        sed -i "s|^${key}=.*|${key}=${value}|" "$YACY_CONF"
    else
        echo "${key}=${value}" >> "$YACY_CONF"
    fi
}

# Proxy-Konfiguration im Hintergrund ausfuehren
if [ -n "$PROXY_HOST" ]; then
    configure_proxy &
fi

# Original YaCy Startbefehl ausfuehren
cd /opt/yacy_search_server
exec sh /opt/yacy_search_server/startYACY.sh -f
