# YaCy im Tor-Netzwerk

Eine Docker-Compose-Konfiguration, die [YaCy](https://yacy.net/) als dezentrale Suchmaschine im Tor-Netzwerk betreibt. Die Instanz ist als Hidden Service (.onion) erreichbar und durchsucht das Tor-Netzwerk ueber einen SOCKS5-Proxy.

Mehrere Knoten koennen sich ueber Tor miteinander vernetzen und Suchergebnisse austauschen.

## Features

- YaCy-Instanz als Tor Hidden Service
- Crawling ueber Tor (SOCKS5-Proxy)
- Vanity .onion-Adressen (optionales Prefix)
- Peer-to-Peer-Vernetzung mehrerer Knoten ueber Tor
- Automatischer Peer-Austausch nach initialem Bootstrap

## Voraussetzungen

- Docker und Docker Compose

## Schnellstart

```bash
# Repository klonen
git clone https://github.com/KayBeckmann/tor-yacy.git
cd tor-yacy

# Konfiguration erstellen
cp env.example .env

# Optional: Vanity-Prefix in .env setzen
# VANITY_PREFIX=yacy

# Starten
docker compose up -d

# .onion-Adresse anzeigen
cat hidden_service/hostname

# Logs verfolgen
docker compose logs -f
```

## Konfiguration

Alle Einstellungen werden ueber die `.env`-Datei vorgenommen:

| Variable | Standard | Beschreibung |
|----------|----------|--------------|
| `VANITY_PREFIX` | *(leer)* | Prefix fuer die .onion-Adresse (a-z, 2-7) |
| `ONION_PORT` | `80` | Port fuer Web-UI im Tor-Netzwerk |
| `PEER_PORT` | `8090` | Port fuer YaCy-Peering ueber Tor |
| `YACY_LOCAL_PORT` | `8090` | Lokaler Port fuer Zugriff auf YaCy |
| `NETWORK_NAME` | `tor` | Name des YaCy-Netzwerks |
| `BOOTSTRAP_PEER` | *(leer)* | .onion-Adresse eines bestehenden Knotens |

### Vanity-Adresse

Das Generieren einer Vanity-Adresse dauert je nach Prefix-Laenge:

| Laenge | Dauer |
|--------|-------|
| 3 Zeichen | Sekunden |
| 4 Zeichen | Minuten |
| 5 Zeichen | Stunden |
| 6 Zeichen | Tage |

## Peering: Mehrere Knoten vernetzen

YaCy-Knoten tauschen ihre Peer-Listen automatisch aus. Sobald ein neuer Knoten ueber einen Bootstrap-Peer verbunden ist, lernt er alle weiteren Knoten im Netzwerk kennen.

### Ersten Knoten aufsetzen (Bootstrap-Peer)

```bash
cp env.example .env
# BOOTSTRAP_PEER leer lassen
docker compose up -d

# Onion-Adresse notieren - diese wird der Bootstrap-Peer
cat hidden_service/hostname
```

### Weitere Knoten hinzufuegen

```bash
cp env.example .env
# In .env die Adresse des Bootstrap-Peers eintragen:
# BOOTSTRAP_PEER=abcdef1234567890.onion

docker compose up -d
```

### Wie funktioniert das Peering?

1. Alle Knoten verwenden denselben `NETWORK_NAME` (Standard: `tor`)
2. Neue Knoten laden die Seed-Liste vom Bootstrap-Peer
3. Ueber die Seed-Liste werden weitere Peers entdeckt
4. Peer-Listen werden automatisch zwischen allen Knoten ausgetauscht
5. Suchergebnisse werden ueber das DHT (Distributed Hash Table) verteilt

```
Knoten A (Bootstrap)
    |
    +--- Knoten B (verbindet sich mit A)
    |        |
    |        +--- Knoten D (entdeckt A und B automatisch)
    |
    +--- Knoten C (verbindet sich mit A)
             |
             +--- entdeckt B und D automatisch
```

## Architektur

```
docker compose
├── tor (Container)
│   ├── Tor Hidden Service (.onion -> YaCy:8090)
│   ├── SOCKS5-Proxy (Port 9050)
│   └── Vanity-Adress-Generator (mkp224o)
│
└── yacy (Container)
    ├── YaCy Suchmaschine (Port 8090)
    ├── Tor-Proxy fuer Crawling
    └── Peering ueber Tor
```

## Dateien

```
tor-yacy/
├── docker-compose.yaml    # Service-Orchestrierung
├── env.example            # Konfigurations-Vorlage
├── .gitignore             # Schuetzt Keys und Daten
├── tor/
│   ├── Dockerfile         # Tor + mkp224o
│   └── entrypoint.sh     # Hidden Service Setup
└── yacy/
    ├── Dockerfile         # YaCy mit Proxy-Konfiguration
    └── configure-proxy.sh # Tor-Proxy + Peering Setup
```

## Sicherheitshinweise

- Der Ordner `hidden_service/` enthaelt private Schluessel - niemals teilen!
- Die `.env`-Datei und `hidden_service/` sind in `.gitignore` eingetragen
- Der SOCKS5-Proxy ist nur innerhalb des Docker-Netzwerks erreichbar
- YaCy ist standardmaessig lokal auf Port 8090 erreichbar - bei Bedarf in `.env` aendern oder den Port-Eintrag in `docker-compose.yaml` entfernen

## Lizenz

MIT
