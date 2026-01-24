FROM yacy/yacy_search_server:latest

USER root
RUN apt-get update && apt-get install -y --no-install-recommends xxd && rm -rf /var/lib/apt/lists/*
COPY configure-proxy.sh /opt/configure-proxy.sh
RUN chmod +x /opt/configure-proxy.sh

ENTRYPOINT ["/opt/configure-proxy.sh"]
