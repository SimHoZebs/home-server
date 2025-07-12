Home Server Infrastructure Documentation
This document provides a detailed overview of a home server setup, which is distributed across two primary machines: a main Debian server and a Raspberry Pi. The system leverages Docker for application containerization, NGINX as a reverse proxy, Tailscale for secure networking, and DuckDNS for dynamic domain name resolution.

High-Level Overview
At its core, this setup provides a suite of self-hosted services, creating a personal cloud for media, photos, analytics, and more. It's designed for security, privacy, and remote accessibility.

System Architecture Diagram
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
The Two Core Devices
debian-server: This is the primary workhorse, equipped with an NVIDIA GPU for hardware-accelerated tasks. It runs the more resource-intensive applications like the media server and photo management system.
rbpi (Raspberry Pi): This is a low-power device dedicated to home automation, location tracking, and remote desktop services.
What Services Are Running?
Here's a quick look at the applications running on the platform:

Service	Host Device	Public Address	Purpose
Jellyfin	debian-server	simtyler.duckdns.org/jellyfin/	GPU-accelerated personal media server.
Immich	debian-server	simpics.duckdns.org	GPU-accelerated photo/video backup solution.
Umami	debian-server	sim-analytics.duckdns.org	Private, open-source web analytics.
Seafile	debian-server	(Internal Access)	File syncing and sharing platform.
Ollama	debian-server	(Internal Access)	GPU-accelerated local large language models.
Home Assistant	rbpi	(Internal Access)	Smart home automation hub.
RustDesk	rbpi	(Internal Access)	Self-hosted remote desktop solution.
OwnTracks	rbpi	(Internal Access)	Private location tracking and logging service.
How It All Connects
Tailscale (Secure Network): All devices are connected to a private, encrypted network using Tailscale. This allows them to communicate securely, no matter where they are in the world.
DuckDNS (Your Address on the Internet): Since a home internet IP address can change, DuckDNS provides free, memorable domain names that always point to the home network.
NGINX (The Digital Doorman): NGINX acts as a reverse proxy. It receives all incoming traffic, checks which domain was requested, and securely forwards the traffic to the correct application container.
Let's Encrypt (The Padlock): All public-facing communication is encrypted with SSL/TLS certificates managed automatically by Certbot.
Low-Level Deep Dive
This section breaks down the technical configuration of each component.

Networking Infrastructure
Tailscale
Tailscale creates a zero-config mesh VPN (a "tailnet") using the WireGuard protocol. This provides a flat, secure network that allows the debian-server and rbpi to communicate directly, as if they were on the same local network.

NGINX Reverse Proxy
NGINX listens on ports 80 (HTTP) and 443 (HTTPS) and routes traffic based on the requested hostname.

HTTP to HTTPS Redirect (Port 80)
This block catches all unencrypted HTTP requests for the public domains and issues a permanent (301) redirect to the secure HTTPS equivalent.

server {
    listen 80;
    server_name simtyler.duckdns.org simpics.duckdns.org sim-analytics.duckdns.org;

    location / {
        return 301 https://$host$request_uri;
    }
}
Main Portal: simtyler.duckdns.org (Port 443)
This block proxies requests for Jellyfin and redirects requests meant for Immich.

# For Jellyfin
location /jellyfin/ {
    # Proxy to the local port where Jellyfin is running
    proxy_pass http://localhost:8096/;
}

# For Immich
location /immich/ {
    # Redirect to the dedicated subdomain for Immich
    return 301 https://simpics.duckdns.org$request_uri;
}
Immich Service: simpics.duckdns.org (Port 443)
This block is dedicated entirely to Immich, proxying all requests to its local container port.

location / {
    proxy_pass http://localhost:2283;
}
Umami Service: sim-analytics.duckdns.org (Port 443)
This block is dedicated to Umami analytics, proxying all requests to its local container port.

location / {
    proxy_pass http://localhost:3000;
}
Docker Containerized Services
Docker is used to run all applications in isolated containers. Below is a summary; see the docker-compose.yml files for full details on volumes and hardware acceleration.

On debian-server
Container Name	Mapped Port	Access
umami	3000	Public via NGINX
immich_server	2283	Public via NGINX
seafile	8585	Internal via Tailscale
jellyfin	8096	Public via NGINX
ollama	11434	Internal via Tailscale
On rbpi
Container Name	Mapped Port(s)	Access
homeassistant	(host network)	Internal via Tailscale
mqtt	1883, 8883	Internal via Tailscale
otrecorder	8083	Internal via Tailscale
hbbs / hbbr	(host network)	Internal via Tailscale
Future Work & Improvements
This section lists planned fixes, enhancements, and other items for future consideration.

1. Correct Fail2ban Implementation
Issue: The fail2ban service is currently configured on the rbpi to monitor Jellyfin logs. However, Jellyfin is running on the debian-server, so its logs are not accessible to the fail2ban instance on the Pi. This means the jail is non-functional and cannot block malicious IPs.
Required Fix:
Migrate Configuration: Install fail2ban on the debian-server.
Recreate Jail: Create the jellyfin.local jail file in /etc/fail2ban/jail.d/ on the debian-server.
Update Log Path: Modify the logpath in the jail to point to the correct location within the Docker volume on the debian-server (e.g., /path/to/jellyfin/config/log/jellyfin*.log).
Verify Action: Ensure the action is correctly set to iptables-allports[name=jellyfin, chain=DOCKER-USER] to interact with Docker's firewall rules.
Decommission Old Jail: Remove the jellyfin.local file from the rbpi to avoid confusion.
2. General Security Hardening
Action: Implement fail2ban jails for other exposed services, such as NGINX itself, to protect against common web attacks and brute-force attempts.
3. Housekeeping
Action: Remove the redundant and empty location /umami/ {} block from the NGINX configuration for simtyler.duckdns.org to clean up the configuration file.
