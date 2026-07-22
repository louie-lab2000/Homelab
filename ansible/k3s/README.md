# K3s HA Cluster Deployment with Ansible - Complete Edition

## Overview

This Ansible playbook deploys a complete 3-node highly available K3s Kubernetes cluster on Debian 13 VMs running in Proxmox, including Rancher for cluster management.

### Architecture

```
                           ┌─────────────────────────────────────┐
                           │         Virtual IP (KubeVIP)        │
                           │          192.168.50.50:6443         │
                           └──────────────┬──────────────────────┘
                                          │
              ┌───────────────────────────┼───────────────────────────┐
              │                           │                           │
              ▼                           ▼                           ▼
    ┌─────────────────┐         ┌─────────────────┐         ┌─────────────────┐
    │     Node-1      │         │     Node-2      │         │     Node-3      │
    │  192.168.50.41  │         │  192.168.50.42  │         │  192.168.50.43  │
    ├─────────────────┤         ├─────────────────┤         ├─────────────────┤
    │ Control Plane   │         │ Control Plane   │         │ Control Plane   │
    │ Worker Node     │         │ Worker Node     │         │ Worker Node     │
    │ etcd member     │         │ etcd member     │         │ etcd member     │
    ├─────────────────┤         ├─────────────────┤         ├─────────────────┤
    │ /dev/sda (32GB) │         │ /dev/sda (32GB) │         │ /dev/sda (32GB) │
    │ System Disk     │         │ System Disk     │         │ System Disk     │
    ├─────────────────┤         ├─────────────────┤         ├─────────────────┤
    │ /dev/sdb(200GB) │         │ /dev/sdb(200GB) │         │ /dev/sdb(200GB) │
    │ Longhorn Storage│         │ Longhorn Storage│         │ Longhorn Storage│
    └─────────────────┘         └─────────────────┘         └─────────────────┘

    MetalLB IP Pool: 192.168.50.60 - 192.168.50.100
    ingress-nginx:   192.168.50.61
```

### Components Installed

| Component | Version | Purpose |
|-----------|---------|---------|
| K3s | Latest stable | Lightweight Kubernetes |
| KubeVIP | v1.0.2 | Virtual IP for API server HA |
| MetalLB | v0.15.2 | LoadBalancer services |
| Longhorn | v1.7.2 | Distributed block storage |
| ingress-nginx | Latest | Ingress controller |
| cert-manager | v1.17.4 (LTS) | TLS certificate management |
| Rancher | Latest stable | Cluster management UI |

---

## Prerequisites

### On Ansible Control Machine

1. Ansible installed (2.12+)
2. SSH key (`~/.ssh/ansible`) with access to all nodes
3. SSH config file (`~/.ssh/config`) with node entries:

```
Host node-1
    HostName 192.168.50.41
    User ansible
    IdentityFile ~/.ssh/ansible

Host node-2
    HostName 192.168.50.42
    User ansible
    IdentityFile ~/.ssh/ansible

Host node-3
    HostName 192.168.50.43
    User ansible
    IdentityFile ~/.ssh/ansible
```

### On Target Nodes

- Fresh Debian 13 installation
- User `ansible` with passwordless sudo
- Second disk attached for Longhorn (auto-detected by size, default 200GB)
- Network configured with static IPs
- Network interface: `ens18` (Proxmox default)

### DNS Configuration

Before running the playbook, add this DNS entry (in pfSense or your DNS server):

| Hostname | IP |
|----------|-----|
| rancher.louielab.cc | 192.168.50.61 |

---

## Quick Start

```bash
# 1. Extract the playbook
tar -xzvf k3s-ansible-complete.tar.gz
cd k3s-ansible-complete

# 2. Install Ansible Galaxy dependencies
ansible-galaxy collection install -r requirements.yml

# 3. Test connectivity
ansible all -m ping

# 4. Run the playbook (takes ~15-20 minutes)
ansible-playbook site.yml
```

---

## Playbook Phases

| Phase | Role | Description |
|-------|------|-------------|
| 1 | prepare | System updates, packages, kernel modules, swap disable |
| 2 | k3s-init | Initialize K3s on first master with cluster-init |
| 3 | kubevip | Deploy KubeVIP for API server HA |
| 4 | k3s-join | Join additional masters to cluster |
| 5 | metallb | Install MetalLB for LoadBalancer services |
| 6 | longhorn-prep | Partition, format, mount storage disks |
| 7 | longhorn | Install Longhorn distributed storage |
| 8 | ingress-nginx | Install NGINX ingress controller |
| 9 | cert-manager | Install cert-manager for TLS |
| 10 | rancher | Install Rancher cluster management |

You can run specific phases using tags:
```bash
ansible-playbook site.yml --tags phase5  # Run only MetalLB
ansible-playbook site.yml --tags rancher  # Run only Rancher
```

---

## Post-Installation

### Web UIs

| Service | URL | Notes |
|---------|-----|-------|
| Rancher | https://rancher.louielab.cc | Bootstrap password: `admin` |
| Longhorn | http://192.168.50.60 | Storage management |

### Access the Cluster

From any node:
```bash
kubectl get nodes
kubectl get pods -A
```

From a remote machine (copy kubeconfig):
```bash
mkdir -p ~/.kube
scp ansible@192.168.50.41:~/.kube/config ~/.kube/config
kubectl get nodes
```

### IP Assignments

| IP | Service |
|----|---------|
| 192.168.50.50 | KubeVIP (K3s API) |
| 192.168.50.60 | Longhorn UI |
| 192.168.50.61 | ingress-nginx (Rancher, all ingresses) |
| 192.168.50.62-100 | Available for future LoadBalancer services |

---

## Configuration

### Key Variables (group_vars/all.yml)

| Variable | Default | Description |
|----------|---------|-------------|
| `node_interface` | ens18 | Network interface (Proxmox default) |
| `kubevip_vip` | 192.168.50.50 | Virtual IP for API server |
| `metallb_ip_range` | 192.168.50.60-192.168.50.100 | IPs for LoadBalancer services |
| `ingress_nginx_ip` | 192.168.50.61 | IP for ingress controller |
| `longhorn_disk_size_gb` | 200 | Size of Longhorn disk (auto-detected) |
| `longhorn_disk_fallback` | /dev/sdb | Fallback if auto-detection fails |
| `rancher_hostname` | rancher.louielab.cc | Rancher URL |
| `rancher_bootstrap_password` | admin | Initial Rancher password |

### Longhorn Disk Auto-Detection

The playbook automatically detects the correct storage disk by size, avoiding the common problem of unstable `/dev/sdX` device names in virtualized environments.

**How it works:**
1. The playbook scans all block devices on each node
2. It finds a disk matching `longhorn_disk_size_gb` (±10% tolerance)
3. If found, uses that disk regardless of its device name (`/dev/sdb`, `/dev/vda`, etc.)
4. If not found, falls back to `longhorn_disk_fallback`

**Benefits:**
- Works regardless of disk controller type (SCSI, SATA, VirtIO)
- No manual configuration needed when sharing the playbook
- Handles VMs where device names change between boots

**To use a different disk size:** Update `longhorn_disk_size_gb` in `group_vars/all.yml`

---

## Troubleshooting

### Issue: SSH Permission Denied
**Solution**: Ensure SSH key permissions are correct:
```bash
chmod 600 ~/.ssh/ansible ~/.ssh/config
```

### Issue: SSH "Can't open user config file ~/.ssh/config"
**Solution**: This was caused by conflicting `-F` flags in ansible.cfg and inventory.
The playbook now uses default SSH behavior and doesn't hardcode paths.
If you still have issues, ensure you don't have `ansible_ssh_common_args` in your inventory.

### Issue: Longhorn Disk Not Found / Wrong Disk Selected
**Solution**: The playbook auto-detects storage disks by size. If detection fails:
1. Check that your storage disk is actually attached
2. Verify the disk size matches `longhorn_disk_size_gb` (±10%)
3. Run `lsblk` on the nodes to see available disks
4. Adjust `longhorn_disk_size_gb` or `longhorn_disk_fallback` in `group_vars/all.yml`

### Issue: K3s API Healthcheck Returns 401
**Solution**: Already handled - playbook accepts 401 as valid (means API is up).

### Issue: Node Not Found in kubectl Commands
**Solution**: Already handled - playbook uses FQDN hostnames (e.g., `node-1.louielab.cc`).

### Issue: cert-manager startupapicheck Timeout
**Solution**: Already handled - startupapicheck is disabled in the Helm install.

### Issue: Ingress Not Getting ADDRESS
**Solution**: Already handled - playbook sets `ingressClassName: nginx`.

### Issue: Longhorn Node Labels Failed
**Solution**: Already handled - playbook uses FQDN hostnames for labels.

---

## Resetting the Cluster

To completely tear down and start fresh:

```bash
ansible-playbook reset.yml
# Type: yes-destroy-my-cluster
```

Then reinstall:
```bash
ansible-playbook site.yml
```

---

## Upgrading the Cluster

To upgrade cluster components to newer versions:

### 1. Update Versions in group_vars/all.yml

Edit the version variables:
```yaml
kubevip_version: "v1.0.2"      # Check: https://github.com/kube-vip/kube-vip/releases
metallb_version: "v0.15.2"     # Check: https://github.com/metallb/metallb/releases
longhorn_version: "v1.7.2"     # Check: https://github.com/longhorn/longhorn/releases
cert_manager_version: "v1.17.4" # Check: helm search repo jetstack/cert-manager --versions
# k3s_version: ""              # Leave empty for latest, or pin e.g. "v1.33.6+k3s1"
```

### 2. Run the Upgrade Playbook

```bash
# Backup etcd first (always!)
ansible-playbook upgrade.yml --tags backup

# Upgrade everything
ansible-playbook upgrade.yml

# Or upgrade specific components
ansible-playbook upgrade.yml --tags k3s
ansible-playbook upgrade.yml --tags kubevip
ansible-playbook upgrade.yml --tags metallb
ansible-playbook upgrade.yml --tags longhorn
ansible-playbook upgrade.yml --tags ingress-nginx
ansible-playbook upgrade.yml --tags cert-manager
ansible-playbook upgrade.yml --tags rancher

# Verify cluster health
ansible-playbook upgrade.yml --tags verify
```

### Upgrade Order Recommendations

For major upgrades, follow this order:
1. **K3s** (rolling upgrade, one node at a time)
2. **KubeVIP** (quick, minimal impact)
3. **MetalLB** (may briefly affect LoadBalancer IPs)
4. **cert-manager** (before Rancher if updating both)
5. **Rancher** (depends on cert-manager)
6. **Longhorn** (storage - be careful, ensure no active I/O)
7. **ingress-nginx** (may briefly affect ingress traffic)

### Rollback

If something goes wrong, restore from etcd backup:
```bash
# On node-1, stop k3s on all nodes first
sudo systemctl stop k3s

# Restore from snapshot
sudo k3s server --cluster-reset --cluster-reset-restore-path=/var/lib/rancher/k3s/server/db/snapshots/<snapshot-name>
```

---

## Files Structure

```
k3s-ansible-complete/
├── ansible.cfg              # Ansible configuration
├── inventory/
│   └── hosts.yml            # Node inventory
├── group_vars/
│   └── all.yml              # Global variables (versions, IPs, etc.)
├── roles/
│   ├── prepare/             # System preparation
│   ├── k3s-init/            # First master setup
│   ├── k3s-join/            # Additional masters
│   ├── kubevip/             # KubeVIP installation
│   ├── metallb/             # MetalLB installation
│   ├── longhorn-prep/       # Disk preparation
│   ├── longhorn/            # Longhorn installation
│   ├── ingress-nginx/       # Ingress controller
│   ├── cert-manager/        # Certificate management
│   └── rancher/             # Rancher installation
├── site.yml                 # Main install playbook
├── upgrade.yml              # Component upgrade playbook
├── reset.yml                # Cluster teardown
└── requirements.yml         # Ansible Galaxy deps
```

---

## Adding New Ingress Services

To expose a new service via ingress:

1. **Add DNS entry in pfSense** pointing to 192.168.50.61
2. **Create an Ingress resource** with `ingressClassName: nginx`

Example:
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app
  namespace: my-namespace
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - myapp.louielab.cc
    secretName: myapp-tls
  rules:
  - host: myapp.louielab.cc
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: my-app-service
            port:
              number: 80
```

---

## Important Notes

1. **Proxmox VMs use `ens18`** - not `eth0` for network interface
2. **K3s registers nodes with FQDN** - all kubectl commands use lowercase hostname
3. **Newer K3s requires auth for /healthz** - playbook accepts 401 status codes
4. **Empty `--node-taint=""` breaks K3s** - flag is omitted entirely
5. **Parted is required** - included in system_packages for disk partitioning
6. **Disk auto-detection by size** - no more hardcoded `/dev/sdb` paths
7. **SSH config handled automatically** - don't add `-F` flags in inventory

---

## Version History

- **v2.2** - Disk auto-detection and SSH fixes
  - Added: Automatic Longhorn disk detection by size (no more unstable /dev/sdX names)
  - Fixed: SSH configuration conflicts between ansible.cfg and inventory
  - Fixed: Removed hardcoded home directory paths for portability
  - Changed: `longhorn_disk` replaced with `longhorn_disk_size_gb` and `longhorn_disk_fallback`
- **v2.1** - Updated versions and user account
  - Updated: KubeVIP v0.8.0 → v1.0.2 (major release with many improvements)
  - Updated: MetalLB v0.14.5 → v0.15.2
  - Updated: Longhorn v1.6.2 → v1.7.2 (stable, well-tested)
  - Updated: cert-manager v1.14.5 → v1.17.4 (LTS release)
  - Changed: User account from `louie` to `ansible`
  - Changed: Hostnames now lowercase (node-1 instead of Node-1)
- **v2.0** - Complete edition with ingress-nginx, cert-manager, and Rancher
  - Added: ingress-nginx role (Phase 8)
  - Added: cert-manager role (Phase 9)
  - Added: rancher role (Phase 10)
  - Fixed: All FQDN hostname issues
  - Fixed: cert-manager startupapicheck disabled
  - Fixed: Rancher ingress ingressClassName set correctly
