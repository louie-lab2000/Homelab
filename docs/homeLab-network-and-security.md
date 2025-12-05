# Home Lab Network & Security Overview

## Infrastructure Summary

- **Proxmox Hosts:** 4 nodes + 1 edge server
- **Edge Server:** Hosts pfSense firewall VM, CrowdSec LXC container, and Cloudflare connector LXC container
- **Network Hardware:** 10 Gb managed switch, NAS devices (Synology DS-1621+, OpenMediaVault secondary NAS), wireless access point with VLAN-tagged SSIDs
- **Remote Access:** Tailscale VPN for secure external access
- **External Exposure:** Cloudflare Tunnels for internet-facing WordPress websites

## Network Architecture

### VLAN Segmentation

Configured in pfSense and switch:

| VLAN | ID | Subnet | Purpose |
|------|----|--------|---------|
| IoT | 21 | 192.168.21.0/24 | Ring cameras, alarm, Home Assistant |
| Television | 22 | 192.168.22.0/24 | TVs and streaming devices |
| Server | 50 | 192.168.50.0/24 | Internet-exposed services, Cloudflare tunnel |
| Home | 51 | 192.168.51.0/24 | Admin PCs and laptops, full admin control |
| Guest | 52 | 192.168.52.0/24 | Untrusted devices, fully locked down |
| Server_mgmt | 100 | 192.168.10.0/24 | Proxmox management interfaces |

### Firewall Philosophy

- Strict inter-VLAN firewalling preventing cross-VLAN communication
- No open inbound firewall ports; all external access via Cloudflare tunnels or Tailscale
- pfBlockerNG-devel implemented to block malicious IPv4 destinations
- DNS security controls: blocking DoH/DoT and port 53 except to pfSense

## DNS & Name Resolution

- pfSense runs Unbound DNS configured as authoritative for DHCP leases and static mappings
- Upstream DNS is Cloudflare 1.1.1.3 (Family DNS with malware filtering) over DNS-over-TLS
- DNSSEC enabled on Unbound

## Firewall & Intrusion Detection

- pfSense firewall in VM on edge Proxmox host
- CrowdSec running in an unprivileged LXC container with AppArmor, providing IP reputation-based intrusion detection and banning
- pfBlockerNG-devel for outbound IP reputation blocking
- Strong firewall and DNS rules to limit lateral movement and prevent DNS exfiltration

## Services & Security

### WordPress Sites

- Hosted in isolated VMs
- Each VM backed up every 2 hours
- WordPress software and plugins also backed up to Cloudflare R2 storage via backup plugin (facilitates future migration to managed hosting)
- Hardened with Wordfence security suite: WAF, geo-blocking, exploit/malware prevention

### Backups

- All VMs backed up daily (or more frequently) to Synology DS-1621+
- All VMs backed up daily (or more frequently) to OpenMediaVault (secondary NAS)
- Synology backed up to second local NAS, Cloudflare R2 object storage, and Synology C2 cloud
- NFS shares and Docker volumes backed up with the same multi-tier approach
- Backups tested regularly with verified restore procedures

## Certificates and Secrets

### Certificate Management

| System | Method |
|--------|--------|
| Proxmox, TrueNAS, OpenMediaVault, pfSense | Built-in ACME tools |
| VMs | Certbot |
| Synology | acme.sh script |
| Docker containers | Nginx Proxy Manager cert function |

DNS challenge used for most certs since the primary domain (louielab.cc) is not externally exposed.

### Secrets Management

- Docker compose YAML files, secrets, and passwords stored in an encrypted folder
- All logins and passwords (other than SSH) stored in Vaultwarden/Bitwarden
- SSH access via MobaXterm with password authentication disabled; public key authentication only

## Monitoring & Logging

- **Log aggregation:** Loki + Grafana
- **Metrics:** Prometheus + cAdvisor (container metrics)
- **Alerting:** Alertmanager
- **Uptime:** Uptime Kuma (external monitoring)

## Access & Authentication

- All external services protected with 2FA (TOTP authenticator)
- Cloudflare management console secured with 2FA
- Tailscale provides secure remote access with enforced ACLs
- Vaultwarden/Bitwarden for password management with strong password enforcement

## Patch & Configuration Management

- Automated OS and software updates via Ansible
- Docker container updates automated using Watchtower
