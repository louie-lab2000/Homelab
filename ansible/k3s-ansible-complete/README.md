# K3s HA Cluster Ansible Playbook

Automated deployment of a 3-node K3s high-availability cluster with embedded etcd, including storage, ingress, load balancing, and cluster management.

## Cluster Overview

| Component | Details |
|-----------|---------|
| Nodes | 3x Debian 13 (Proxmox VMs or bare metal) |
| K3s | Latest stable, embedded etcd |
| API VIP | 192.168.50.50 (KubeVIP) |
| Load Balancer | MetalLB (192.168.50.60-100) |
| Storage | Longhorn (200GB per node) |
| Ingress | ingress-nginx (192.168.50.61) |
| Certificates | cert-manager |
| Management | Rancher |

## Node Configuration

| Node | IP | FQDN |
|------|-----|------|
| node-1 | 192.168.50.41 | node-1.louielab.cc |
| node-2 | 192.168.50.42 | node-2.louielab.cc |
| node-3 | 192.168.50.43 | node-3.louielab.cc |

## Prerequisites

- Ansible control machine with `kubectl` and `helm`
- SSH key access to all nodes (user: `ansible`)
- Debian 13 installed on all nodes with static IPs
- Passwordless sudo configured for ansible user

## Quick Start
```bash
# Install required Ansible collections
ansible-galaxy collection install -r requirements.yml

# Test connectivity
ansible all -m ping

# Deploy the cluster
ansible-playbook site.yml
```

## Available Playbooks

### Core Cluster

| Playbook | Description |
|----------|-------------|
| `site.yml` | Full cluster deployment (K3s, KubeVIP, MetalLB, Longhorn, ingress-nginx, cert-manager, Rancher) |
| `reset.yml` | Destroy cluster completely (requires confirmation) |
| `upgrade.yml` | Upgrade K3s to latest version |

### Add-on Services

| Playbook | Description |
|----------|-------------|
| `configure-storage-nic.yml` | Configure second NIC (ens19) for storage VLAN access |
| `install-nfs-csi.yml` | Install NFS CSI driver with Synology StorageClass |
| `deploy-pulse.yml` | Deploy Pulse Proxmox monitoring dashboard |

## Deployment Phases

The `site.yml` playbook runs these roles in order:

1. **prepare** - System packages, kernel modules, sysctl settings
2. **k3s-init** - Initialize first master node
3. **kubevip** - Deploy API server VIP
4. **k3s-join** - Join additional master nodes
5. **metallb** - Deploy load balancer
6. **longhorn-prep** - Partition and mount storage disks
7. **longhorn** - Deploy distributed storage
8. **ingress-nginx** - Deploy ingress controller
9. **cert-manager** - Deploy certificate management
10. **rancher** - Deploy cluster management UI

## IP Assignments

| IP | Service |
|----|---------|
| 192.168.50.50 | KubeVIP (K3s API) |
| 192.168.50.60 | Longhorn UI |
| 192.168.50.61 | ingress-nginx / Rancher |
| 192.168.50.62 | Pulse (if deployed) |
| 192.168.50.63-100 | Available |

## Web UIs

| Service | URL |
|---------|-----|
| Rancher | https://rancher.louielab.cc |
| Longhorn | http://192.168.50.60 |
| Pulse | http://192.168.50.62 (if deployed) |

## Common Commands
```bash
# Check cluster status
kubectl get nodes
kubectl get pods -A

# Check specific namespaces
kubectl get pods -n cattle-system       # Rancher
kubectl get pods -n longhorn-system     # Longhorn
kubectl get pods -n ingress-nginx       # Ingress
kubectl get pods -n metallb-system      # LoadBalancer

# View services and IPs
kubectl get svc -A

# SSH to nodes
ssh node-1
ssh node-2
ssh node-3
```

## Reset Cluster
```bash
ansible-playbook reset.yml
# Type: yes-destroy-my-cluster
```

## Storage Classes

After full deployment with NFS CSI:

| StorageClass | Type | Use Case |
|--------------|------|----------|
| longhorn (default) | Replicated block | Databases, stateful apps |
| nfs-synology | NFS shared | Multi-pod access, media |

## Configuration

Primary configuration is in `group_vars/all.yml`:

- `node_interface` - Network interface (default: ens18)
- `kubevip_vip` - API server VIP
- `metallb_ip_range` - LoadBalancer IP pool
- `longhorn_disk_size_gb` - Auto-detect storage disk by size
- `rancher_hostname` - Rancher FQDN

## Physical Deployment

When migrating from Proxmox VMs to bare metal, update:

- `node_interface` - Physical NIC name (eth0, eno1, enp0s31f6, etc.)
- `longhorn_disk_fallback` - Verify disk device path
- Add firmware packages if needed

Run these commands on physical nodes to discover correct values:
```bash
ip link show              # Find NIC name
lsblk                     # Find disk devices
```

## Namespaces

| Namespace | Contents |
|-----------|----------|
| kube-system | K3s core, KubeVIP, CoreDNS |
| cattle-system | Rancher |
| longhorn-system | Longhorn storage |
| ingress-nginx | NGINX ingress controller |
| cert-manager | Certificate management |
| metallb-system | MetalLB load balancer |
| nfs-provisioner | NFS CSI driver (if deployed) |
| pulse | Pulse monitoring (if deployed) |

## Known Issues & Solutions

| Issue | Solution |
|-------|----------|
| Proxmox interface is ens18, not eth0 | Set `node_interface: ens18` in group_vars |
| K3s uses FQDN hostnames | Playbook handles lowercase conversion |
| cert-manager startupapicheck timeout | Disabled in playbook |
| Ingress has no ADDRESS | Ensure `ingressClassName: nginx` is set |

## Adding New Ingress Services

1. Add DNS entry in pfSense pointing to 192.168.50.61
2. Create Ingress resource:
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app
  namespace: my-namespace
spec:
  ingressClassName: nginx
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

## Directory Structure
```
k3s-cluster/
├── ansible.cfg
├── requirements.yml
├── README.md
├── site.yml
├── reset.yml
├── upgrade.yml
├── configure-storage-nic.yml
├── install-nfs-csi.yml
├── deploy-pulse.yml
├── inventory/
│   └── hosts.yml
├── group_vars/
│   └── all.yml
└── roles/
    ├── cert-manager/
    ├── ingress-nginx/
    ├── k3s-init/
    ├── k3s-join/
    ├── kubevip/
    ├── longhorn/
    ├── longhorn-prep/
    ├── metallb/
    ├── prepare/
    └── rancher/
```