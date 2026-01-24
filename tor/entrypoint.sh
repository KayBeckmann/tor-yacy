#!/bin/bash
set -e

VANITY_PREFIX="${VANITY_PREFIX:-}"
YACY_HOST="${YACY_HOST:-yacy}"
YACY_PORT="${YACY_PORT:-8090}"
ONION_PORT="${ONION_PORT:-80}"
PEER_PORT="${PEER_PORT:-8090}"
HIDDEN_SERVICE_DIR="/var/lib/tor/hidden_service"

# Vanity-Adresse generieren falls Prefix gesetzt und keine Keys vorhanden
if [ -n "$VANITY_PREFIX" ] && [ ! -f "$HIDDEN_SERVICE_DIR/hs_ed25519_secret_key" ]; then
    echo "Generiere Vanity-Adresse mit Prefix: $VANITY_PREFIX"
    echo "Dies kann je nach Prefix-Laenge lange dauern..."

    WORK_DIR=$(mktemp -d)
    cd "$WORK_DIR"

    mkp224o -n 1 -d "$WORK_DIR/results" "$VANITY_PREFIX"

    # Ergebnis in Hidden Service Verzeichnis kopieren
    RESULT_DIR=$(find "$WORK_DIR/results" -mindepth 1 -maxdepth 1 -type d | head -1)

    if [ -n "$RESULT_DIR" ]; then
        mkdir -p "$HIDDEN_SERVICE_DIR"
        cp "$RESULT_DIR/hostname" "$HIDDEN_SERVICE_DIR/"
        cp "$RESULT_DIR/hs_ed25519_secret_key" "$HIDDEN_SERVICE_DIR/"
        cp "$RESULT_DIR/hs_ed25519_public_key" "$HIDDEN_SERVICE_DIR/"
        echo "Vanity-Adresse generiert: $(cat $HIDDEN_SERVICE_DIR/hostname)"
    else
        echo "FEHLER: Keine Adresse generiert!"
        exit 1
    fi

    rm -rf "$WORK_DIR"
fi

# Verzeichnis erstellen falls nicht vorhanden und Berechtigungen setzen
mkdir -p "$HIDDEN_SERVICE_DIR"
chown -R debian-tor:debian-tor "$HIDDEN_SERVICE_DIR"
chmod 700 "$HIDDEN_SERVICE_DIR"

# Tor-Konfiguration erstellen
cat > /etc/tor/torrc << EOF
# SOCKS-Proxy (intern fuer Privoxy)
SocksPort 127.0.0.1:9050

# Hidden Service Konfiguration
HiddenServiceDir $HIDDEN_SERVICE_DIR
HiddenServicePort $ONION_PORT $YACY_HOST:$YACY_PORT
EOF

# Peering-Port nur hinzufuegen wenn verschieden vom Onion-Port
if [ "$PEER_PORT" != "$ONION_PORT" ]; then
    echo "HiddenServicePort $PEER_PORT $YACY_HOST:$YACY_PORT" >> /etc/tor/torrc
fi

cat >> /etc/tor/torrc << EOF

# Logging
Log notice stdout
EOF

# Privoxy als HTTP-zu-SOCKS5-Bridge konfigurieren
cat > /etc/privoxy/config << EOF
listen-address  0.0.0.0:8118
forward-socks5  /  127.0.0.1:9050  .
toggle  0
enable-remote-toggle  0
enable-edit-actions  0
enable-remote-http-toggle  0
EOF

echo "Starte Privoxy (HTTP-Proxy auf Port 8118 -> Tor SOCKS5)..."
privoxy /etc/privoxy/config

echo "Starte Tor..."
echo "Hidden Service: Port $ONION_PORT (Web) + Port $PEER_PORT (Peering) -> $YACY_HOST:$YACY_PORT"

# Warte kurz und zeige dann die .onion-Adresse
(sleep 10 && if [ -f "$HIDDEN_SERVICE_DIR/hostname" ]; then
    echo "==================================="
    echo "Onion-Adresse: $(cat $HIDDEN_SERVICE_DIR/hostname)"
    echo "==================================="
fi) &

exec runuser -u debian-tor -- tor -f /etc/tor/torrc
