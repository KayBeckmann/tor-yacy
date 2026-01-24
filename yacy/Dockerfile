FROM yacy/yacy_search_server:latest

COPY configure-proxy.sh /opt/configure-proxy.sh
RUN chmod +x /opt/configure-proxy.sh

ENTRYPOINT ["/opt/configure-proxy.sh"]
