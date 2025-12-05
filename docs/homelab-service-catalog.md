# Home Lab Service Catalog

**Last Updated:** December 2025

This catalog documents all user-facing services, their network details, and hosting dependencies.

---

## Service Summary

| Service | Purpose |
|---------|---------|
| Discourse Forum | Community discussion forum |
| WordPress (Production) | Food blog and recipe site |
| WordPress (Professional) | Personal and professional blog |
| WordPress (Test) | Test environment |
| PaperlessNGX | Document management and OCR system |
| Vaultwarden | Password manager (Bitwarden-compatible) |
| Grafana Stack | System monitoring and log aggregation |
| Linkwarden | Bookmark and research archive |
| Nextcloud | Private cloud file storage |
| SearXNG | Meta search engine |
| Uptime Kuma | Service monitoring dashboard |

---

## Network Details

| Service | URL | IP Address | Port(s) |
|---------|-----|------------|---------|
| Discourse Forum | forum.louiecloud.com | 192.168.50.20 | 80, 443 |
| WordPress (Production) | *.com (tunneled) | 192.168.50.25 | 80, 443 |
| PaperlessNGX | paperless.louielab.cc | 192.168.51.15 | 8000 |
| Vaultwarden | vw.louielab.cc | 192.168.51.15 | 8080 |
| Grafana Stack | grafana.louielab.cc | 192.168.50.2 | 3000, 9090, 3100 |
| Linkwarden | linkwarden.louielab.cc | 192.168.51.15 | 5000 |
| WordPress (Professional) | *.com (tunneled) | 192.168.50.22 | 80, 443 |
| Nextcloud | nextcloud.louiecloud.com | 192.168.50.3 | 443 |
| SearXNG | search.louielab.cc | 192.168.51.15 | 8081 |
| WordPress (Test) | test.*.com (tunneled) | 192.168.50.26 | 80, 443 |
| Uptime Kuma | kuma.louielab.cc | 192.168.51.15 | 3001 |

**Note:** Services on `louielab.cc` are internal-only (resolved by pfSense DNS). Services on public domains are accessed via Cloudflare Tunnels — no ports exposed to the internet.

---

## Hosting & Dependencies

| Service | Host | Dependencies |
|---------|------|--------------|
| Discourse Forum | VM on PVE-01 | Postgres, Redis, Cloudflare |
| WordPress (Production) | VM on PVE-01 | MariaDB, Cloudflare CDN, Synology backups |
| PaperlessNGX | Docker on Synology | Redis, Postgres, NFS storage |
| Vaultwarden | Docker on PVE-10 | Synology NFS volume |
| Vaultwarden Backup | Synology NAS | Hyper Backup, Cloudflare R2 |
| Grafana Stack | Docker on PVE-01 | Prometheus, Loki, Node Exporter |
| Linkwarden | Docker on PVE-10 | Postgres, Synology NFS |
| WordPress (Professional) | VM on PVE-01 | MariaDB, Cloudflare CDN, Synology backups |
| Nextcloud | Docker on PVE-01 | MariaDB, Redis, Synology NFS |
| SearXNG | Docker on PVE-10 | Synology NFS |
| WordPress (Test) | VM on PVE-01 | MariaDB, Cloudflare CDN |
| Uptime Kuma | Docker on PVE-10 | SMTP or Slack alerts |

---

## Access Patterns

### External Access (via Cloudflare Tunnels)

- WordPress sites (production and test)
- Discourse forum
- Nextcloud

### Internal Access Only (louielab.cc)

- Grafana / Prometheus / Loki
- Vaultwarden
- PaperlessNGX
- Linkwarden
- SearXNG
- Uptime Kuma

Internal services are accessed via Tailscale VPN when off-network.

---

## Related Documentation

| Document | Contents |
|----------|----------|
| Homelab Overview | Infrastructure summary |
| Software Catalog | Container inventory, Portainer config |
| Network & Security | VLAN configuration, firewall rules |
