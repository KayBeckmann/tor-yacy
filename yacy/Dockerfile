FROM yacy/yacy_search_server:latest

USER root

# PeerActions.java patchen: virgin/junior Peers nicht ablehnen
# In Tor-Netzwerken funktioniert der Erreichbarkeitstest nicht,
# daher muessen alle Peers akzeptiert werden unabhaengig vom Typ.
RUN sed -i '/peerType.equals(Seed.PEERTYPE_VIRGIN)/,/return false;/{/return false;/d}' \
        /opt/yacy_search_server/source/net/yacy/peers/PeerActions.java && \
    sed -i '/!(peerType.equals(Seed.PEERTYPE_SENIOR)/,/return false;/{/return false;/d}' \
        /opt/yacy_search_server/source/net/yacy/peers/PeerActions.java && \
    cd /opt/yacy_search_server && \
    javac -cp "build/classes/java/main:lib/*" \
        -d build/classes/java/main \
        source/net/yacy/peers/PeerActions.java

COPY yacy.network.tor.unit /opt/yacy_search_server/defaults/yacy.network.tor.unit
COPY configure-proxy.sh /opt/configure-proxy.sh
RUN chmod +x /opt/configure-proxy.sh

ENTRYPOINT ["/opt/configure-proxy.sh"]
