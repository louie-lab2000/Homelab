# Synology Services Overview

**Last Updated:** December 2025  
**Model:** Synology DS-1621+ (6-bay)

This document covers the Synology NAS configuration, performance optimizations, services, and backup strategy.

---

## Hardware Configuration

| Component | Specification |
|-----------|---------------|
| Model | DS-1621+ |
| Drives | Seagate Ironwolf (5900 RPM) |
| Cache | Dual NVMe SSD (read/write cache) |
| Filesystem | BTRFS |
| Network | Dual 10GbE (Intel X710) on dedicated storage VLAN |

---

## Performance Architecture

### NVMe Caching Strategy

The NAS uses NVMe SSDs as a read/write cache with BTRFS metadata pinned to the cache pool. This configuration delivers SSD-class performance for typical homelab workloads despite using slower 5900 RPM spinning disks.

**What hits the NVMe cache:**

- All BTRFS metadata operations (directory listings, file lookups, inode updates)
- Frequently accessed "hot" data blocks
- All write operations (write-back cache)
- Small random I/O patterns typical of containers and databases

**What hits spinning disks:**

- Large sequential reads/writes (bulk file transfers, video editing)
- Cold data not accessed recently
- Cache eviction overflow

**Result:** For typical workloads — Docker volumes, database queries, file sync, photo thumbnails — the NAS performs at NVMe speeds. The spinning disks only engage for bulk operations or when accessing rarely-used files.

### Network Configuration

The NAS connects via dual 10GbE NICs on a dedicated non-routed storage VLAN. This VLAN carries only storage traffic (NFS, SMB, iSCSI) and is not routed through the firewall, eliminating network bottlenecks and firewall overhead for storage I/O.

---

## NFS Configuration and Optimizations

Docker hosts and VMs mount Synology NFS exports for persistent storage. The following mount options are used for optimal performance and reliability:

```
vers=4.2,nconnect=4,noatime,soft,timeo=30,retrans=3
```

| Option | Purpose |
|--------|---------|
| `vers=4.2` | NFSv4.2 — latest protocol version with improved locking and performance |
| `nconnect=4` | Opens 4 parallel TCP connections per mount, improving throughput |
| `noatime` | Disables access time updates, reducing unnecessary write I/O |
| `soft` | Returns errors on timeout instead of hanging indefinitely |
| `timeo=30` | 3-second timeout before retry (in deciseconds) |
| `retrans=3` | Retry 3 times before failing |

The `soft` mount with reasonable timeouts prevents Docker containers from hanging indefinitely if the NAS becomes temporarily unreachable (e.g., during a reboot or network hiccup). Containers fail fast and can be restarted cleanly rather than becoming zombies.

---

## K3s CSI Driver Integration (Planned)

The Synology NAS is planned as a storage backend for the K3s cluster using the democratic-csi driver. This will provide:

- Dynamic PersistentVolume provisioning via NFS
- Storage classes for different performance tiers
- Snapshot and clone capabilities
- Centralized storage management through Kubernetes

Current K3s storage uses Longhorn on local disks. Migration to Synology-backed CSI will consolidate storage and simplify backup workflows.

---

## Native Synology Services

### Synology Drive

Provides file synchronization across multiple devices. Family members use Drive to sync their Documents folders between laptops and workstations.

**Configuration:**

- Server: Synology Drive Server package
- Clients: Synology Drive Client on Windows/Mac
- Selective sync enabled (users choose which folders to sync)
- Version history retained for 32 versions
- Conflict resolution: keep both copies with timestamp suffix

**Volumes synced:**

- Personal document folders (per-user volumes)
- Shared collaboration folders

Drive is preferred over SMB for mobile devices because it handles intermittent connectivity gracefully and provides offline access to synced files.

### Synology Photos

Photo management and sharing for the household. The Photos volume is accessible via:

- Synology Photos web interface and mobile app
- Direct SMB mount for local editing with desktop applications

Photos handles thumbnail generation, facial recognition, and timeline organization. The NVMe cache significantly accelerates thumbnail rendering and search operations.

---

## Docker on Synology

### PaperlessNGX

PaperlessNGX runs as a Docker Compose stack directly on the Synology, providing document management and OCR capabilities.

**Why on Synology:**

- Documents are already stored on the NAS — no network transfer for ingestion
- Simplifies backup (container data lives alongside document storage)
- Reduces VM/container sprawl on Proxmox hosts
- Survives independently if Proxmox infrastructure is being worked on

**Stack location:** Docker data stored in a dedicated volume, Compose files managed via Portainer agent.

---

## Backup Strategy

The backup architecture follows a 3-2-1 principle with local redundancy and offsite copies.

### Backup Destinations

| Destination | Type | Method | Retention |
|-------------|------|--------|-----------|
| **USB SSD #1** | Local-single version | Hyper Backup | Daily, 30 versions |
| **USB SSD #2** | Local-multi version | Hyper Backup | Daily, 30 versions |
| **Cloudflare R2** | Offsite (cloud)-multi version | Hyper Backup (S3) | Daily, 90 versions |
| **Synology C2** | Offsite (cloud)-multi version | Hyper Backup (C2) | Daily, 90 versions |

### USB SSD Backup Drives

Two enterprise SATA SSDs are connected via USB 3.0 enclosures:

- Physically attached to the Synology for direct backup
- One volume is a single version backup (can access files direct from disk) the other volume is a multiple version backup
- Encrypted with Hyper Backup encryption
- Fast restore capability for local disasters

### Cloudflare R2

Object storage backup using S3-compatible protocol:

- No egress fees (critical for restore operations)
- Encrypted in transit and at rest
- Hyper Backup handles incremental block-level deduplication
- Cost-effective for multi-TB datasets

### Synology C2

Native Synology cloud backup:

- Tight DSM integration
- Bare-metal restore capability
- Automatic version management
- Secondary offsite location (geographic redundancy from R2)

### What Gets Backed Up

| Data | Backup Targets |
|------|----------------|
| User volumes (documents, photos, media) | USB SSDs, R2, C2 |
| Docker volumes (PaperlessNGX, etc.) | USB SSDs, R2 |
| Synology configuration | C2 (config backup) |
| Proxmox VM backups | Stored on Synology, then backed up to R2 |

---

## Power Protection

### UPS Integration

The Synology NAS is protected by a CyberPower CP850PFCLCD UPS and participates in the Network UPS Tools (NUT) infrastructure.

**Power chain:**

```
Wall Outlet → EcoFlow Delta 2 → CyberPower UPS → Synology
```

The EcoFlow provides extended runtime and whole-room backup. The CyberPower provides clean power, surge protection, and NUT signaling.

### NUT Client Configuration

Synology's built-in UPS support connects to the NUT server running on PVE-01:

- **Network UPS server:** PVE-01 (192.168.10.2)
- **UPS name:** `cyberpower`
- **Safe mode:** Enabled — Synology enters safe mode when UPS signals low battery
- **Shutdown:** Graceful shutdown triggered by NUT before UPS exhaustion

This ensures the NAS completes any pending writes and unmounts volumes cleanly before power loss, protecting BTRFS integrity.

---

## Maintenance Notes

### BTRFS Scrub

Monthly scrub scheduled to detect and repair bit rot:

```
Storage Manager → Storage Pool → Action → Data Scrubbing
```

Scrub runs with low priority to minimize performance impact.

### Drive Health

SMART monitoring enabled with email alerts. S.M.A.R.T. extended tests scheduled monthly.
Synology Active Insight monitoring service subscription
Synology C2 Storage manager and explorer service subscription

### Package Updates

DSM and packages updated during maintenance windows. Critical security updates applied promptly.

---

## Related Documentation

| Document | Contents |
|----------|----------|
| Homelab Overview | Infrastructure summary |
| Software Catalog | Container inventory, Portainer config |
| Network & Security | VLAN configuration, NFS export rules |
