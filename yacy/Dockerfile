FROM yacy/yacy_search_server:latest

USER root

# PeerActions.java patchen: virgin/junior Peers nicht ablehnen
# In Tor-Netzwerken funktioniert der Erreichbarkeitstest nicht,
# daher muessen alle Peers akzeptiert werden unabhaengig vom Typ.
# Methode 1: Entferne alle "return false" nach Peer-Type-Checks
RUN sed -i '/peerType.equals(Seed.PEERTYPE_VIRGIN)/,/return false;/{/return false;/d}' \
        /opt/yacy_search_server/source/net/yacy/peers/PeerActions.java && \
    sed -i '/!(peerType.equals(Seed.PEERTYPE_SENIOR)/,/return false;/{/return false;/d}' \
        /opt/yacy_search_server/source/net/yacy/peers/PeerActions.java && \
    # Methode 2: Ersetze PEERTYPE_VIRGIN und PEERTYPE_JUNIOR Checks durch true
    sed -i 's/peerType\.equals(Seed\.PEERTYPE_VIRGIN)/false/g' \
        /opt/yacy_search_server/source/net/yacy/peers/PeerActions.java && \
    sed -i 's/peerType\.equals(Seed\.PEERTYPE_JUNIOR)/false/g' \
        /opt/yacy_search_server/source/net/yacy/peers/PeerActions.java && \
    # Methode 3: Ersetze NOT QUALIFIED Check durch akzeptiere alle
    sed -i 's/!peerType\.equals(Seed\.PEERTYPE_SENIOR) && !peerType\.equals(Seed\.PEERTYPE_PRINCIPAL)/false/g' \
        /opt/yacy_search_server/source/net/yacy/peers/PeerActions.java && \
    # Neucompilieren
    cd /opt/yacy_search_server && \
    javac -cp "build/classes/java/main:lib/*" \
        -d build/classes/java/main \
        source/net/yacy/peers/PeerActions.java

COPY yacy.network.tor.unit /opt/yacy_search_server/defaults/yacy.network.tor.unit
COPY configure-proxy.sh /opt/configure-proxy.sh
RUN chmod +x /opt/configure-proxy.sh

ENTRYPOINT ["/opt/configure-proxy.sh"]
