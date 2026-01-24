FROM yacy/yacy_search_server:latest

USER root
COPY yacy.network.tor.unit /opt/yacy_search_server/defaults/yacy.network.tor.unit
COPY configure-proxy.sh /opt/configure-proxy.sh
RUN chmod +x /opt/configure-proxy.sh

ENTRYPOINT ["/opt/configure-proxy.sh"]
