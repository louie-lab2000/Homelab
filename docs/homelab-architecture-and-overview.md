# Homelab Overview

**Last Updated:** December 2025

This document provides a high-level summary of the homelab environment. See the companion documents for detailed specifications: Hardware Inventory, Network & Security, Service Catalog, Software Catalog, and Synology Services.

---

## Architecture Summary

Four standalone Proxmox VE hosts connected via a 10GbE backbone, with a virtualized pfSense firewall providing VLAN segmentation across six network zones. Primary storage runs on a Synology NAS with NVMe caching; experimental storage on a TrueNAS VM backed by enterprise SSDs. A 3-node K3s cluster provides a Kubernetes learning environment. All external access routes through Cloudflare Tunnels — no inbound firewall ports exposed.

---

## Compute Infrastructure

| Node | Hardware | CPU | RAM | Role |
|------|----------|-----|-----|------|
| **PVE-01** | Custom Mini-ITX (Gigabyte B550i) | Ryzen 5 Pro 5650GE | 64GB ECC | Primary compute: WordPress, Discourse, Home Assistant, TrueNAS VM |
| **PVE-02** | HP Elite Mini 800 G9 | i5-12500T | 64GB | K3s cluster host (3 VMs) |
| **PVE-03** | GMKtec Nucbox G3 | Intel N100 | 16GB | Ansible control node, OpenMediaVault backup target |
| **PVE-10** | ASRock Rack IMBV-2000M | — | Limited | "Production island": pfSense, Vaultwarden, CrowdSec, Cloudflared, Uptime Kuma |

**Design note:** PVE-10 is the "never touch" node — services here must be always-on. LXC containers communicate with the pfSense VM at memory speed over Proxmox's internal bridge.

---

## Storage Infrastructure

| System | Hardware | Capacity | Role |
|--------|----------|----------|------|
| **Synology DS-1621+** | 5900 RPM Ironwolf + NVMe R/W cache | Multi-TB | Primary storage: Drive, Photos, PaperlessNGX, SMB, Proxmox backups, offsite to Cloudflare R2 |
| **TrueNAS Scale** (VM) | 4× 2TB Samsung SM863a + NVMe L2ARC | 4TB usable | Experimental ZFS storage, future K3s backend |

Synology performance is optimized by pinning BTRFS metadata to NVMe cache — typical workloads hit cache speeds despite spinning disks.

---

## K3s Cluster

Three-node HA cluster running entirely on PVE-02, deployed via Ansible.

| Component | Configuration |
|-----------|---------------|
| Nodes | 192.168.50.41-43 |
| API VIP | 192.168.50.50 (KubeVIP) |
| Load Balancer | MetalLB (.60-.100) |
| Ingress | ingress-nginx on .61 |
| Storage | Longhorn (200GB per node) |
| Management | Rancher |

---

## Network Architecture

| Component | Details |
|-----------|---------|
| Firewall | pfSense CE (VM on PVE-10) |
| Switch | QNAP QSW-M3216R-8S8T (10GbE managed) |
| External Access | Cloudflare Tunnels (zero exposed ports) |
| Remote Admin | Tailscale VPN |
| DNS | Unbound on pfSense, upstream to Cloudflare 1.1.1.3 over DoT, DNSSEC enabled |

### VLAN Segmentation

| VLAN | Subnet | Purpose |
|------|--------|---------|
| 21 | 192.168.21.0/24 | IoT (cameras, sensors, Home Assistant) |
| 22 | 192.168.22.0/24 | TV/Media (streaming devices) |
| 50 | 192.168.50.0/24 | Servers (K3s, internet-exposed services) |
| 51 | 192.168.51.0/24 | Home (trusted devices, full access) |
| 52 | 192.168.52.0/24 | Guest (isolated) |
| 100 | 192.168.10.0/24 | Management (Proxmox interfaces) |

A dedicated non-routed storage VLAN carries NAS traffic. An air-gapped management network on a separate dumb switch provides out-of-band access to IPMI/DASH interfaces.

---

## Key Services

| Category | Services |
|----------|----------|
| **Infrastructure** | pfSense, Pi-hole, CrowdSec, Cloudflared, Ansible |
| **Monitoring** | Prometheus, Loki, Uptime Kuma, Alertmanager |
| **Productivity** | Synology Drive, Synology Photos, Vaultwarden, PaperlessNGX |
| **Web/Apps** | WordPress (×2), Discourse, Home Assistant |
| **Storage** | TrueNAS Scale, OpenMediaVault, Hyper Backup to R2 |

All Docker stacks are defined in Compose files stored on Synology and deployed via Portainer. See the Software Catalog for container details and secrets management.

---

## Power & Reliability

| Component | Function |
|-----------|----------|
| EcoFlow Delta 2 | Battery backup / line conditioning |
| CyberPower CP850PFCLCD | UPS with NUT integration |

All Proxmox hosts monitor the UPS via Network UPS Tools for coordinated clean shutdowns.

---

## Design Principles

1. **Stability over features** — Critical services run on a dedicated "production island" isolated from experimentation.
2. **10GbE backbone** — All compute and storage nodes on 10GbE with a dedicated non-routed storage VLAN.
3. **Enterprise storage at homelab prices** — Samsung SM863a SSDs throughout; reliable and affordable on secondary market.
4. **Defense in depth** — VLAN segmentation, CrowdSec IDS, Cloudflare Tunnels, pfBlockerNG, air-gapped management.
5. **Infrastructure as code** — Docker Compose on Synology, K3s via Ansible, moving toward full GitOps.

---

## Related Documentation

| Document | Contents |
|----------|----------|
| Hardware Inventory | Detailed specs, IPs, component lists |
| Network & Security | VLAN config, firewall rules, DNS, diagrams |
| Service Catalog | URLs, ports, dependencies, status flags |
| Software Catalog | Container inventory, Portainer config, secrets handling |
| Synology Services | Volumes, users, backup jobs, native apps |
