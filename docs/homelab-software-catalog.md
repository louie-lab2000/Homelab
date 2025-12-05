# Home Lab Software Catalog

**Last Updated:** December 2025

This document catalogs all software (VMs, containers, stacks) in the home lab, maps software to hardware, and documents Docker Compose/Portainer management. Unless noted, container images use the `:latest` tag and are managed via Portainer. All Compose YAML files live centrally on Synology.

---

## Software-to-Hardware Mapping

| Host | Role | Software / Containers | Notes |
|------|------|----------------------|-------|
| **PVE-01** | Primary Proxmox Node | — | Hosts 7 VMs |
| ↳ TrueNAS SCALE | Experimental NAS | rsyncd, portainer-agent | Not critical |
| ↳ Docker-int (Debian) | Primary Docker host | alertmanager, cadvisor, grafana, heimdall, linkwarden, loki, meilisearch, postgres, prometheus, redis, searxng | Stacks: monitoring, apps |
| ↳ WordPress #1 | Production blog | WordPress, MariaDB | — |
| ↳ WordPress #2 | Production blog | WordPress, MariaDB | — |
| ↳ WordPress #3 | Test blog | WordPress, MariaDB | Test environment |
| ↳ Home Assistant OS | Home automation | HAOS (supervised) | Runs as VM |
| **PVE-02** | K3s Host | — | 4 Debian VMs |
| ↳ Node-1 | Cluster control plane | k3s server | — |
| ↳ Node-2 | Cluster control plane | k3s server | — |
| ↳ Node-3 | Cluster control plane | k3s server | — |
| ↳ Cluster Admin | Admin/jump host | kubectl, helm, tooling | — |
| **PVE-03** | Automation / Backup | — | Debian + OMV VM |
| ↳ Debian VM | Automation | ansible, terraform | Admin automation host |
| ↳ OpenMediaVault | Backup target + Docker | portainer-agent, promtail, node-exporter | Secondary backup |
| **PVE-10** | Edge Server | — | 2 LXCs + 2 VMs |
| ↳ cloudflared (LXC) | Tunnel endpoint | cloudflared | Unattended updates |
| ↳ crowdsec (LXC) | Security/IPS | crowdsec | — |
| ↳ pfSense (VM) | Routing/Firewall | pfSense CE | — |
| ↳ Docker-edge (VM) | Edge Docker host | librespeed, nginx-proxy-manager, portainer-agent, uptime-kuma, vaultwarden | Edge services |
| **Synology DS-1621+** | NAS + Docker | PaperlessNGX stack, portainer-agent | — |

---

## Software Inventory by Domain

### Infrastructure

| Software | Location | Purpose |
|----------|----------|---------|
| pfSense CE | PVE-10 VM | Routing, firewall, VLANs |
| Proxmox VE | PVE-01, PVE-02, PVE-03, PVE-10 | Hypervisor |
| Synology DSM | DS-1621+ | NAS, Docker, backups |
| TrueNAS SCALE | PVE-01 VM | Experimental NAS for K3s |
| OpenMediaVault | PVE-03 VM | Backup target + Docker |

### Container Orchestration & Automation

| Software | Location | Purpose |
|----------|----------|---------|
| Docker | Docker-int, Docker-edge, Synology, OMV, TrueNAS | Container runtime |
| Portainer | Docker-int (server) + agents | Centralized container management |
| Ansible | PVE-03 VM | Configuration management |
| Terraform | PVE-03 VM | Infrastructure automation |
| K3s | PVE-02 VMs | Lightweight Kubernetes (lab) |
| Watchtower | Docker-int, Docker-edge | Automated container updates |

### Monitoring / Observability

| Software | Location | Purpose |
|----------|----------|---------|
| Prometheus | Docker-int | Metrics collection |
| Loki | Docker-int | Log aggregation |
| Grafana | Docker-int | Dashboards |
| Alertmanager | Docker-int | Alert routing |
| cAdvisor | Docker-int | Container metrics |
| Promtail | OMV VM | Log shipping to Loki |
| Node Exporter | OMV VM | Host metrics |
| Uptime Kuma | Docker-edge | External endpoint monitoring |

### Applications / Frontends

| Software | Location | Purpose |
|----------|----------|---------|
| WordPress (×3) | PVE-01 VMs | Blogs (prod ×2, test ×1) |
| Heimdall | Docker-int | Dashboard/launcher |
| Linkwarden | Docker-int | Bookmark/archive manager |
| SearXNG | Docker-int | Meta search engine |
| PaperlessNGX | Synology | Document management + OCR |
| Vaultwarden | Docker-edge | Password manager |
| Librespeed | Docker-edge | Speed test |
| Nginx Proxy Manager | Docker-edge | Reverse proxy + cert management |
| Home Assistant OS | PVE-01 VM | Home automation |

### Networking / Access / Security

| Software | Location | Purpose |
|----------|----------|---------|
| Cloudflared | PVE-10 LXC | Tunnel for secure external access |
| CrowdSec | PVE-10 LXC | IPS/behavioral security |
| Postgres | Docker-int | Database (Linkwarden, PaperlessNGX) |
| Redis | Docker-int, Synology | Cache/queue |
| MeiliSearch | Docker-int | Search index for Linkwarden |

---

## Docker Compose & Portainer Management

All stacks are defined in Compose YAML files stored on the Synology NAS and deployed via Portainer. The Portainer server runs on Docker-int; agents run on Docker-edge, OMV, TrueNAS, and Synology. Images are `:latest` unless stability requires a pin.

### Stack Inventory

| Stack | Host | Core Containers | Dependencies |
|-------|------|-----------------|--------------|
| **Monitoring** | Docker-int | grafana, prometheus, loki, alertmanager, cadvisor | Synology NFS volumes |
| **Linkwarden** | Docker-int | linkwarden, meilisearch, postgres | Synology NFS |
| **SearXNG** | Docker-int | searxng, redis | Local volume |
| **Edge** | Docker-edge | nginx-proxy-manager, librespeed, uptime-kuma, vaultwarden | Cloudflared tunnel |
| **PaperlessNGX** | Synology | paperlessngx, redis, postgres, gotenburg, tika | Synology Docker volume |
| **OMV Agents** | OMV VM | portainer-agent, promtail, node-exporter | Loki/Prometheus on Docker-int |
| **TrueNAS Agents** | TrueNAS VM | rsyncd, portainer-agent | — |

---

## Rebuild & Maintenance Notes

**Deployment method:** Portainer (server on Docker-int) with agents on Docker-edge, OMV, TrueNAS, and Synology.

**To redeploy a stack:**

1. Ensure NFS mounts to Synology are available
2. In Portainer, create a new stack and point to the Synology-hosted Compose YAML
3. Apply `.env` from secrets path
4. Deploy

**Updates:** Watchtower handles `:latest` tagging; review monthly. Pin versions if a regression occurs.

**Persistence:** Verify Synology volumes are mounted before starting services to avoid data path recreation.

**Monitoring:** Confirm Prometheus and Loki retention configs; validate Alertmanager routes; ensure Uptime Kuma monitors are green.

---

## Related Documentation

| Document | Contents |
|----------|----------|
| Homelab Overview | Infrastructure summary |
| Service Catalog | URLs, ports, access details |
| Synology Services | NAS configuration, backups |
