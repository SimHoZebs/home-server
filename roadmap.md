# Home Server: Practical Roadmap

This roadmap is tailored for a technically experienced home user, focusing on essential improvements for data safety, privacy, reproducibility, backup, and monitoring. Non-essential and overkill tasks have been removed or simplified. Advanced features can be added if needs grow.

---

### Automated SSL/TLS Certificate Management
Problem Statement:
SSL/TLS certificates for services running on rbpi (managed via `rbpi/docker-compose.yaml` and NGINX) are currently renewed manually using Certbot and DuckDNS. This risks downtime and security lapses if renewal is missed, and there is no automated alerting for failures or expiry.

Solution Steps:
1. Schedule Certbot’s `renew` command via cron or systemd timer (e.g., every 12 hours).
2. Use DuckDNS DNS challenge for domain validation.
3. Configure Certbot `--deploy-hook` to reload NGINX after renewal.
4. Set up email notifications for renewal failures.
5. Monitor certificate expiry and Certbot logs.
6. Test automation with `certbot renew --dry-run`.

Acceptance Criteria:
- All public-facing services have valid, auto-renewed certificates.
- NGINX reloads automatically after renewal.
- Renewal failures trigger notifications.
- Certificate expiry is monitored and alerts are configured.

---

### Automated Backups with Offsite/Cloud Sync
Problem Statement:
Critical data—including media files, configuration files in `debian-server/` and `rbpi/`, and Umami analytics stored in PostgreSQL—is only backed up locally. There is no automated, encrypted offsite backup configured for either debian-server or rbpi, leaving data vulnerable to hardware failure or accidental deletion.

Solution Steps:
1. Select and configure backup tool (e.g., Restic, Borg) for all critical data.
2. Schedule regular, encrypted backups to offsite/cloud storage.
3. Test backup and restore procedures quarterly.
4. Document backup strategy and recovery steps simply.

Acceptance Criteria:
- All critical data is backed up offsite on a regular schedule.
- Backups are encrypted and restorable.
- Backup and restore procedures are documented and tested.

---

### Basic Monitoring & Alerting
Problem Statement:
Resource usage and service health are not tracked in real time, making it difficult to detect failures or performance issues across containers and hosts.

Solution Steps:
1. Deploy lightweight monitoring tools (Netdata, Glances, or email alerts) across all nodes and containers.
2. Configure alerts for disk space, CPU, RAM, and service downtime.
3. Integrate simple dashboards for visual status overview (optional).

Acceptance Criteria:
- All nodes and containers are monitored for resource and service health.
- Alerts are triggered for failures and critical thresholds.
- Dashboards provide real-time visibility (optional).

---

### Hardware Health Monitoring
Problem Statement:
Disk health (SMART), SD card status, and hardware metrics for debian-server and rbpi are not monitored. Failures may go undetected, risking data loss and outages, especially for rbpi nodes running critical services.

Solution Steps:
1. Enable SMART monitoring for disks and use Pi-specific tools for SD card and hardware health.
2. Set up email alerts for hardware degradation or failure.

Acceptance Criteria:
- All hardware is monitored for health and degradation.
- Alerts are triggered for hardware issues.
- Hardware monitoring is documented.

---

### Disaster Recovery Drills & Documentation
Problem Statement:
Backup restore and service recovery procedures for debian-server and rbpi have not been tested in a controlled drill. Documentation is incomplete, risking extended downtime and data loss in the event of failure.

Solution Steps:
1. Schedule and execute regular disaster recovery drills (at least annually).
2. Test full backup restore and service recovery.
3. Document recovery procedures and lessons learned.
4. Update documentation after each drill.

Acceptance Criteria:
- Disaster recovery procedures are tested and documented.
- Full backup restore is proven to work.
- Documentation is updated after each drill.

---

### Security Hardening Items
Problem Statement:
Default passwords, missing security headers, root containers, and lax firewall rules present security risks across the home server stack.

Solution Steps:
1. Update all `.env` files and Docker secrets to use strong, unique passwords (use a password manager for generation and storage).
2. Add security headers (`Strict-Transport-Security`, `X-Frame-Options`, `Content-Security-Policy`, `X-Content-Type-Options`, `Referrer-Policy`) to all NGINX configs.
3. Update Docker Compose files to run containers as non-root users where possible.
4. Regularly renew Let's Encrypt certificates using Certbot.
5. Set up UFW or iptables on debian-server and rbpi to restrict access to only necessary ports.
6. Add rate limiting to NGINX configs.

Acceptance Criteria:
- All credentials and secrets are strong and unique.
- NGINX configs include recommended security headers and rate limiting.
- Containers run as non-root users where possible.
- SSL certificates are renewed and monitored.
- Firewall rules restrict access to only necessary ports.
- Security hardening steps are documented and reviewed regularly.

---

### Automated Container Updates
Problem Statement:
Containers on both debian-server and rbpi are updated manually. There is no automated update tool (e.g., Watchtower) configured, leaving services exposed to vulnerabilities and increasing maintenance overhead.

Solution Steps:
1. Deploy automated update tool (e.g., Watchtower).
2. Configure update schedule and rollback procedures.
3. Test updates and monitor for failures.
4. Document update strategy and recovery steps.

Acceptance Criteria:
- Containers are updated automatically on a regular schedule.
- Rollback procedures are tested and documented.
- Update strategy is documented.

---

### Self-Hosted Status Page (Optional)
Problem Statement:
There is no centralized status dashboard (e.g., Uptime Kuma) for services running on debian-server and rbpi. Service health and uptime are not easily visible to administrators.

Solution Steps:
1. Deploy self-hosted status page (e.g., Uptime Kuma) if desired.
2. Integrate health checks for all critical services.
3. Document status page configuration and usage.

Acceptance Criteria:
- Status page is deployed and accessible (optional).
- Health checks are integrated for all critical services.
- Configuration and usage are documented.

---

### Nextcloud & Arr Suite
Problem Statement:
Current platform choices (e.g., Seafile for file sync, manual media management) may not offer optimal ecosystem integration, mobile sync, or automation.

Solution Steps:
1. Migrate from Seafile to Nextcloud for improved ecosystem and mobile sync.
2. Deploy Arr suite (Prowlarr, Sonarr, Radarr, qBittorrent) for automated media management.
3. Document migration steps, configuration changes, and integration points.

Acceptance Criteria:
- Nextcloud and Arr suite are deployed and integrated.
- Media automation and sync capabilities are improved and documented.

---

### Umami Migration to rbpi
Problem Statement:
Umami analytics is currently deployed on debian-server. To optimize resource usage and centralize web services, Umami should be migrated to rbpi, with all analytics data and PostgreSQL volumes transferred.

Solution Steps:
1. Plan migration of Umami service from debian-server to rbpi.
2. Migrate volume data (e.g., PostgreSQL backend, analytics data) over the network.
3. Update service inventory and architecture documentation.

Acceptance Criteria:
- Umami is running on rbpi with all historical data preserved.
- Service inventory and architecture docs are updated.
- Functionality and data integrity are verified.

---

### PostgreSQL Container & Database Consolidation
Problem Statement:
Multiple PostgreSQL containers are running across debian-server, each serving different services (Umami, Immich). This increases resource usage and maintenance complexity. Consolidation into a single container with multiple databases is needed.

Solution Steps:
1. Plan consolidation of PostgreSQL containers into a single instance.
2. Migrate separate service databases (e.g., Umami, AppFlowy, Immich) into distinct databases within the same container.
3. Update service configurations to point to the unified instance.
4. Test backup, restore, and service connectivity.

Acceptance Criteria:
- All services use a single PostgreSQL container with separate databases.
- Service configs are updated and tested.
- Backup and restore procedures are verified.

