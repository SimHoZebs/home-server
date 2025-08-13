# Home Server Architecture
Multi-node home server infrastructure distributed across debian-server (primary) and rbpi (Raspberry Pi). Uses Docker containerization, NGINX reverse proxy, Tailscale mesh networking, and DuckDNS dynamic DNS.

All services are currently operational and validated via container inspection.

## Architecture Overview
Self-hosted service stack providing media streaming, photo management, analytics, file sync, LLM inference, and home automation.

## System Architecture Diagram
@startuml

package "The Internet" {
  cloud "User's Browser" as User
}

package "Home Network" {
    actor Router
    package "debian-server" as DebianServer {
        component "NGINX Reverse Proxy" as NGINX
        DebianServer -- NGINX
        package "Docker on Debian" {
            rectangle "Jellyfin" as Jellyfin
            rectangle "Immich Stack" as Immich
            rectangle "Umami Stack" as Umami
            rectangle "Seafile Stack" as Seafile
            rectangle "Ollama" as Ollama
            rectangle "AppFlowy-Cloud" as AppFlowy
        }
    }

    package "rbpi" as RPi {
        package "Docker on RPi" {
            rectangle "Home Assistant" as HA
            rectangle "RustDesk"
            rectangle "OwnTracks Stack" as OwnTracks
        }
    }
}

frame "Tailscale Secure Network" {
    DebianServer -- RPi
}


User --> Router
Router --> NGINX : Ports 80, 443

NGINX --> Jellyfin : simtyler.duckdns.org/jellyfin
NGINX --> Immich : simpics.duckdns.org
NGINX --> Umami : sim-analytics.duckdns.org
NGINX --> AppFlowy : appflowy.duckdns.org

note right of DebianServer
  **Internal-Only Services**
  (Accessed via Tailscale)
  - Seafile
  - Ollama
end note

note right of RPi
  **Internal-Only Services**
  (Accessed via Tailscale)
  - Home Assistant
  - RustDesk
  - OwnTracks
end note

@enduml
## Infrastructure Components
- **debian-server**: Primary server with NVIDIA GPU for hardware acceleration
- **rbpi**: Raspberry Pi for home automation and remote access services

## Service Inventory

| Service | Host Device | Public Address | Purpose |
| :--- | :--- | :--- | :--- |
| **Jellyfin** | `debian-server` | `simtyler.duckdns.org/jellyfin/` | GPU-accelerated media server |
| **Immich** | `debian-server` | `simpics.duckdns.org` | GPU-accelerated photo/video management |
| **Umami** | `debian-server` | `sim-analytics.duckdns.org` | Web analytics platform |
| **Seafile** | `debian-server` | (Internal Access) | File sync with MariaDB backend |
| **Ollama** | `debian-server` | (Internal Access) | GPU-accelerated LLM inference |
| **Streamer** | `debian-server` | (Internal Access) | GPU-accelerated SRT to RTMP relay |
| **AppFlowy-Cloud** | `debian-server` | `appflowy.duckdns.org` | Collaboration platform backend |
| **Home Assistant**| `rbpi` | (Internal Access) | Home automation hub |
| **RustDesk** | `rbpi` | (Internal Access) | Remote desktop service |
| **OwnTracks** | `rbpi` | (Internal Access) | Location tracking service |

### Ollama LLM Service
GPU-accelerated LLM inference service on debian-server (port 11434, internal access).

#### Model Portfolio
| Model | Size | Classification | Use Case |
|-------|------|----------------|----------|
| qwen3:1.7b | 1.4 GB | Speed | Low-latency inference |
| phi4-mini | 2.5 GB | Speed | Quick interactions |
| qwen3:4b | 2.6 GB | General | Balanced performance |
| gemma3:4b | 3.3 GB | Multimodal | Text and vision processing |
| qwen3:latest | 5.2 GB | Intelligence | Complex reasoning |
| deepseek-r1:8b | 5.2 GB | Intelligence | Advanced problem-solving |

**Model Selection Strategy:**
- Speed models: Instant responses, real-time applications
- General models: Balanced capability/performance for standard tasks  
- Intelligence models: Complex reasoning where latency is acceptable
- Multimodal: Handles both text and image processing

### Streaming Service
GPU-accelerated SRT to RTMP relay service for live streaming to multiple platforms.

**Configuration:**
- **Input**: SRT stream on configurable UDP port with low latency buffering
- **Outputs**: Simultaneous RTMP streams to YouTube and Twitch
- **Hardware acceleration**: NVDEC for decoding, H.264 NVENC for encoding
- **Audio processing**: AAC encoding at 48kHz

## Network Architecture
- **Tailscale**: WireGuard-based mesh VPN providing secure inter-device communication
- **DuckDNS**: Dynamic DNS service for stable domain resolution to changing home IP
- **NGINX**: Reverse proxy with SSL termination and traffic routing
- **Let's Encrypt**: Automated SSL/TLS certificate management via Certbot

## Technical Implementation

### Network Infrastructure
#### Tailscale Mesh Network
WireGuard-based VPN creating secure communication between debian-server and rbpi.

#### NGINX Configuration
Multiple NGINX instances handle different routing requirements:

**AppFlowy-Cloud Internal NGINX** (`AppFlowy-Cloud/nginx/nginx.conf`):
- SSL termination with self-signed certificates
- Routes to multiple backend services: API (port 8000), GoTrue auth (9999), Admin (3000), Web (80), MinIO (9000/9001)
- WebSocket support for real-time collaboration
- Large file upload support (up to 2GB)

**External Proxy Template** (`AppFlowy-Cloud/external_proxy_config/nginx/appflowy.site.conf`):
- Configuration template for external reverse proxy setups
- HTTP-only, designed for external SSL termination

**Seafile NGINX** (backup configuration in `seafile_backup/data/nginx/`):
- Document server reverse proxy for Seafile services
- WebSocket support for notifications
- Multiple service endpoints (Seahub, file HTTP, WebDAV)

### Seafile FUSE Integration
Seafile service configured with privileged access and SYS_ADMIN capability for FUSE mounting. Library mounted to `/seafile-fuse` internally, shared read-only to other containers via `/mnt/hdd1/seafile/seafile-fuse:/seafile-external:ro`. Enables direct file access for services like Immich without API overhead.

### Container Deployment
All services containerized via Docker. Configuration details in `compose.yaml` and service-specific compose files.

#### debian-server Containers
| Container Name | Mapped Port | Access | Notes |
| :--- | :--- | :--- | :--- |
| `umami` | 3000 | Public via NGINX | Running with PostgreSQL backend (db-umami) |
| `immich_server` | 2283 | Public via NGINX | Multi-container stack: server, ML, Redis, PostgreSQL with vector support. Has read-only access to Seafile files via FUSE mount at `/seafile-external`. |
| `seafile` | 8585 | Internal via Tailscale | Running with MariaDB backend and Memcached. Provides a FUSE mount of its file library for other containers. |
| `jellyfin` | Host network | Public via NGINX | GPU-accelerated transcoding with NVIDIA runtime |
| `ollama` | 11434 | Internal via Tailscale | GPU-accelerated with NVIDIA runtime |
| `streamer` | SRT_PORT/udp | Internal | GPU-accelerated SRT to RTMP relay with NVIDIA runtime |
| `AppFlowy-Cloud` | 80, 443 | Public via own NGINX | Complex stack: API, auth (GoTrue), admin, web, MinIO, PostgreSQL |

#### rbpi Containers
*(Configuration not present in this repository)*

| Container Name | Mapped Port(s) | Access |
| :--- | :--- | :--- |
| `homeassistant` | (host network) | Internal via Tailscale |
| `mqtt` | 1883, 8883 | Internal via Tailscale |
| `otrecorder` | 8083 | Internal via Tailscale |
| `hbbs` / `hbbr` | (host network) | Internal via Tailscale |

## Operational Status
- **12 active containers** across all services
- **GPU acceleration** operational (NVIDIA runtime)
- **Database backends** running: PostgreSQL, MariaDB
- **Caching layers** active: Redis, Memcached
- **Health checks** passing

## Implementation Notes

### 1. Fail2ban Configuration Issue
- **Current**: fail2ban on rbpi monitoring Jellyfin logs on debian-server (non-functional)
- **Required**: Migrate fail2ban to debian-server, update jail configuration for correct log paths

### 2. Security Hardening Items
- **Default passwords** in environment files require strengthening
- **NGINX security headers** missing (HSTS, X-Frame-Options, CSP)
- **Container security**: Services running as root
- **SSL certificates**: AppFlowy self-signed certs likely expired
- **Firewall rules**: No UFW/iptables configuration
- **Rate limiting**: Not configured in NGINX

### 3. Platform Migration Considerations
- **Seafile → Nextcloud**: Evaluate ecosystem benefits and mobile sync capabilities
- **Media Automation**: Implement Arr suite (Prowlarr, Sonarr, Radarr, qBittorrent) for automated content management
