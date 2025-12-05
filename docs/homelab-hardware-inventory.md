# Home Lab Hardware Inventory

## Overview

This document provides a complete inventory of all physical hardware components in the home lab environment. It includes compute, storage, network, backup, power, and IoT devices.

## Hardware Summary

| Host | Model | CPU | RAM | Storage | Network | IP | Purpose |
|------|-------|-----|-----|---------|---------|-----|---------|
| PVE-01 | Custom build | Ryzen 5 Pro 5650GE | 64 GB ECC | 2 TB ZFS mirror | Dual 10 GbE SFP+ | 192.168.10.2 | Production |
| PVE-02 | HP Elite Mini 800 G9 | i5-12500T | 64 GB | 1 TB ZFS mirror | 10 GBase-T | 192.168.10.3 | K3s node |
| PVE-03 | Intel N100 mini | N100 | 16 GB | 1 TB NVMe | 2.5 GbE | 192.168.10.4 | Ansible/OMV/TrueNAS |
| PVE-04 | HP Z640 | Xeon E5-2690v3 | 64 GB ECC | Variable | Dual 10 GbE SFP+ | 192.168.10.5 | Sandbox/Dev |
| PVE-10 | Custom build | Ryzen V2718 | 16 GB | 256 GB SSD | Dual 10 GbE + 2x RealTek | 192.168.10.6 | pfSense/Edge |
| Synology | DS-1621+ | Ryzen V1500B | 32 GB ECC | 6-bay SHR + NVMe cache | Dual 10 GbE | 192.168.51.2 | Storage/Docker/Backups |

## Detailed Hardware Inventory

### PVE-01

- **Model:** Custom build (Fractal Designs Node 304 case / Gigabyte B550I Aorus Pro AX Mini-ITX)
- **CPU:** AMD Ryzen 5 Pro 5650GE (6 cores / 12 threads)
- **RAM:** 64 GB ECC
- **Storage:** Four 1 TB Samsung SM863A enterprise SSDs in ZFS RAID-10 mirror (2 TB usable)
- **Network:** Dual 10 Gb SFP+ (Intel X520)
- **IP:** 192.168.10.2
- **Purpose:** Production workloads

### PVE-02

- **Model:** HP Elite Mini 800 G9
- **CPU:** Intel i5-12500T (6 cores / 12 threads)
- **RAM:** 64 GB non-ECC
- **Storage:** Dual NVMe SSD in ZFS mirror (1 TB usable)
- **Network:** Single 10 GBase-T
- **IP:** 192.168.10.3
- **Purpose:** K3s cluster node

### PVE-03

- **Model:** Intel N100 mini system
- **CPU:** Intel N100 (4 cores / 4 threads)
- **RAM:** 16 GB non-ECC
- **Storage:** Single 1 TB NVMe SSD
- **Network:** Single 2.5 GbE
- **IP:** 192.168.10.4
- **Purpose:** Ansible, OMV, TrueNAS SCALE (backup and automation)

### PVE-04

- **Model:** HP Z640
- **CPU:** Intel Xeon E5-2690v3 (12 cores / 24 threads)
- **RAM:** 64 GB ECC
- **Storage:** Variable - multiple SATA SSDs/HDDs swapped as needed; Asus M.2 PCIe card for dual NVMe (requires bifurcation)
- **Network:** Dual 10 Gb SFP+ (Intel X520)
- **IP:** 192.168.10.5
- **Purpose:** Sandbox and development

### PVE-10 (Edge Server)

- **Model:** Custom build (ASRock Industrial IMB-V2000M / 4L SFF case)
- **CPU:** AMD Ryzen SoC V2718 (8 cores / 16 threads)
- **RAM:** 16 GB non-ECC (ECC capable)
- **Storage:** 256 GB SATA SSD
- **Network:** Dual 10 Gb (AOC + RJ45 SFP+ via Intel X520) plus two onboard RealTek NICs
- **IP:** 192.168.10.6
- **Purpose:** pfSense, Cloudflared, edge workloads

### Synology DS-1621+

- **Model:** Synology DS-1621+
- **CPU:** AMD Ryzen V1500B
- **RAM:** 32 GB ECC
- **Storage:** 6-bay NAS (4x 4 TB HDDs in SHR, 2x 1 TB WD NVMe as read/write cache with metadata pinned to the cache)
- **Network:** Dual 10 GbE (Intel X550)
- **IP:** 192.168.51.2
- **Purpose:** Central storage, Docker host, backups

## Network & Power Infrastructure

| Device | Model | Purpose | Notes |
|--------|-------|---------|-------|
| Managed Switch | QNAP QSW-M3216R-8S8T | Core 10 GbE interconnects | All hosts and VLANs |
| UPS | CyberPower ST425 | Battery backup / surge protection | Connected to EcoFlow |
| Battery | EcoFlow Delta 2 | Extended runtime | Supplements UPS |
| Cable Modem | Netgear CX700 | Primary WAN | Owned |
| 5G Gateway | T-Mobile | Secondary WAN (failover) | — |
| Digital Radio | PiStar Hotspot | Raspberry Pi radio bridge 
| Security Hub | Ring Base Station | Smart home / cameras 


