# Home Server Infrastructure Documentation
This document provides a detailed overview of a home server setup, which is distributed across two primary machines: a main Debian server and a Raspberry Pi. The system leverages Docker for application containerization, NGINX as a reverse proxy, Tailscale for secure networking, and DuckDNS for dynamic domain name resolution.

**Note:** This document reflects the current state of the server infrastructure as analyzed from the repository and running containers. All services listed are actively running and have been validated through Docker container inspection.

## High-Level Overview
At its core, this setup provides a suite of self-hosted services, creating a personal cloud for media, photos, analytics, and more. It's designed for security, privacy, and remote accessibility.

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
## The Two Core Devices
- **debian-server**: This is the primary workhorse, equipped with an NVIDIA GPU for hardware-accelerated tasks. It runs the more resource-intensive applications like the media server and photo management system.
- **rbpi (Raspberry Pi)**: This is a low-power device dedicated to home automation, location tracking, and remote desktop services. *(Note: Configuration for this device is not present in this repository).*

## What Services Are Running?
Here's a quick look at the applications running on the platform:

| Service | Host Device | Public Address | Purpose |
| :--- | :--- | :--- | :--- |
| **Jellyfin** | `debian-server` | `simtyler.duckdns.org/jellyfin/` | GPU-accelerated personal media server. |
| **Immich** | `debian-server` | `simpics.duckdns.org` | GPU-accelerated photo/video backup solution. |
| **Umami** | `debian-server` | `sim-analytics.duckdns.org` | Private, open-source web analytics. *(Running and healthy)* |
| **Seafile** | `debian-server` | (Internal Access) | File syncing and sharing platform. *(Running with MariaDB backend)* |
| **Ollama** | `debian-server` | (Internal Access) | GPU-accelerated local large language models. |
| **AppFlowy-Cloud** | `debian-server` | `appflowy.duckdns.org` | Backend for the AppFlowy application (auth, storage, collaboration). |
| **Home Assistant**| `rbpi` | (Internal Access) | Smart home automation hub. |
| **RustDesk** | `rbpi` | (Internal Access) | Self-hosted remote desktop solution. |
| **OwnTracks** | `rbpi` | (Internal Access) | Private location tracking and logging service. |

## How It All Connects
- **Tailscale (Secure Network)**: All devices are connected to a private, encrypted network using Tailscale. This allows them to communicate securely, no matter where they are in the world.
- **DuckDNS (Your Address on the Internet)**: Since a home internet IP address can change, DuckDNS provides free, memorable domain names that always point to the home network.
- **NGINX (The Digital Doorman)**: NGINX acts as a reverse proxy. It receives all incoming traffic, checks which domain was requested, and securely forwards the traffic to the correct application container. The configuration appears to be managed both at a host-level and within specific service directories (e.g., `AppFlowy-Cloud`).
- **Let's Encrypt (The Padlock)**: All public-facing communication is encrypted with SSL/TLS certificates managed automatically by Certbot.

## Low-Level Deep Dive
This section breaks down the technical configuration of each component.

### Networking Infrastructure
#### Tailscale
Tailscale creates a zero-config mesh VPN (a "tailnet") using the WireGuard protocol. This provides a flat, secure network that allows the `debian-server` and `rbpi` to communicate directly, as if they were on the same local network.

#### NGINX Reverse Proxy
NGINX configurations handle routing for different services:

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

### Docker Containerized Services
Docker is used to run all applications in isolated containers. Below is a summary; see the `compose.yaml` and service-specific `docker-compose.yml` files for full details.

#### On `debian-server`
| Container Name | Mapped Port | Access | Notes |
| :--- | :--- | :--- | :--- |
| `umami` | 3000 | Public via NGINX | Running with PostgreSQL backend (db-umami) |
| `immich_server` | 2283 | Public via NGINX | Multi-container stack: server, ML, Redis, PostgreSQL with vector support |
| `seafile` | 8585 | Internal via Tailscale | Running with MariaDB backend and Memcached |
| `jellyfin` | Host network | Public via NGINX | GPU-accelerated transcoding with NVIDIA runtime |
| `ollama` | 11434 | Internal via Tailscale | GPU-accelerated with NVIDIA runtime |
| `AppFlowy-Cloud` | 80, 443 | Public via own NGINX | Complex stack: API, auth (GoTrue), admin, web, MinIO, PostgreSQL |

#### On `rbpi`
*(Note: The configuration for these services is not present in this repository and is listed for informational purposes.)*

| Container Name | Mapped Port(s) | Access |
| :--- | :--- | :--- |
| `homeassistant` | (host network) | Internal via Tailscale |
| `mqtt` | 1883, 8883 | Internal via Tailscale |
| `otrecorder` | 8083 | Internal via Tailscale |
| `hbbs` / `hbbr` | (host network) | Internal via Tailscale |

## Current Infrastructure Status
All services are currently **running and healthy** based on Docker container inspection:
- **11 active containers** including core services and their dependencies
- **GPU acceleration** properly configured for Jellyfin, Immich ML, and Ollama using NVIDIA runtime
- **Database backends** operational: PostgreSQL (Immich, Umami, AppFlowy), MariaDB (Seafile)
- **Caching layers** active: Redis (Immich), Memcached (Seafile)
- **Health checks** passing for all critical services

## Future Work & Improvements
This section lists planned fixes, enhancements, and other items for future consideration.

### 1. Correct Fail2ban Implementation
- **Issue**: The `fail2ban` service is currently configured on the `rbpi` to monitor Jellyfin logs. However, Jellyfin is running on the `debian-server`, so its logs are not accessible to the fail2ban instance on the Pi. This means the jail is non-functional and cannot block malicious IPs.
- **Required Fix**:
  - **Migrate Configuration**: Install `fail2ban` on the `debian-server`.
  - **Recreate Jail**: Create the `jellyfin.local` jail file in `/etc/fail2ban/jail.d/` on the `debian-server`.
  - **Update Log Path**: Modify the `logpath` in the jail to point to the correct location within the Docker volume on the `debian-server` (e.g., `/path/to/jellyfin/config/log/jellyfin*.log`).
  - **Verify Action**: Ensure the `action` is correctly set to `iptables-allports[name=jellyfin, chain=DOCKER-USER]` to interact with Docker's firewall rules.
  - **Decommission Old Jail**: Remove the `jellyfin.local` file from the `rbpi` to avoid confusion.

### 2. General Security Hardening
- **Action**: Implement `fail2ban` jails for other exposed services, such as NGINX itself, to protect against common web attacks and brute-force attempts.

### 3. Security Hardening Requirements
- **Critical Issues**:
  - **Default Passwords**: Multiple weak default passwords found in environment files:
    - `SEAFILE_ADMIN_PASSWORD=asecret`
    - `UMAMI_DB_PASSWORD=umami` 
    - Various database passwords need strengthening
  - **Missing Security Headers**: NGINX configurations lack HSTS, X-Frame-Options, X-Content-Type-Options, CSP
  - **Container Security**: Services run as root without user restrictions
  - **SSL Certificates**: Self-signed certificates for AppFlowy-Cloud are likely expired (March 2024)

### 4. Missing Security Infrastructure
- **Firewall Configuration**: No UFW or iptables rules found
- **Intrusion Detection**: No security monitoring or logging configurations
- **Backup Encryption**: Database backups stored in plain text without encryption
- **Rate Limiting**: No rate limiting configured in NGINX
- **SSH Security**: SSH configurations not tracked in repository
