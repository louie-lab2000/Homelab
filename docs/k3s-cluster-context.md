# Louie's K3s HA Cluster - Context for Future Chats

## Quick Reference

**Paste this at the start of new chats about your K3s cluster:**

```
I have a 3-node K3s HA cluster with the following setup:
- Nodes: Node-1 (192.168.50.41), Node-2 (192.168.50.42), Node-3 (192.168.50.43)
- Domain: louielab.cc (nodes are node-1.louielab.cc, etc.)
- VIP (KubeVIP): 192.168.50.50
- MetalLB IP range: 192.168.50.60-192.168.50.100
- Storage: Longhorn on /dev/sdb (200GB per node) mounted at /var/lib/longhorn
- OS: Debian 13 (Trixie) on Proxmox VMs
- Network interface: ens18
- User: ansible
- Longhorn UI: http://192.168.50.60
- Rancher UI: https://rancher.louielab.cc (192.168.50.61)
- Ingress Controller: ingress-nginx on 192.168.50.61
- cert-manager installed (for TLS certificates)
- Admin machine has kubectl and helm configured
- Ansible playbook: k3s-ansible-complete.tar.gz (includes Rancher)
```

---

## Cluster Details

### Nodes

| Node | IP | FQDN | System Disk | Storage Disk |
|------|-----|------|-------------|--------------|
| Node-1 | 192.168.50.41 | node-1.louielab.cc | /dev/sda (32GB) | /dev/sdb (200GB) |
| Node-2 | 192.168.50.42 | node-2.louielab.cc | /dev/sda (32GB) | /dev/sdb (200GB) |
| Node-3 | 192.168.50.43 | node-3.louielab.cc | /dev/sda (32GB) | /dev/sdb (200GB) |

**Important**: K3s registers nodes using lowercase FQDN (e.g., `node-1.louielab.cc`)

### Installed Components

| Component | Version | Purpose | Notes |
|-----------|---------|---------|-------|
| K3s | Latest stable | Kubernetes | Embedded etcd for HA |
| KubeVIP | v1.0.2 | API VIP | ARP mode on ens18, VIP: 192.168.50.50 |
| MetalLB | v0.15.2 | LoadBalancer | L2 mode, range: 192.168.50.60-100 |
| Longhorn | v1.7.2 | Storage | Default StorageClass, UI: 192.168.50.60 |
| ingress-nginx | Latest | Ingress Controller | LoadBalancer IP: 192.168.50.61 |
| cert-manager | v1.17.4 (LTS) | TLS Certificates | Self-signed, can add Let's Encrypt |
| Rancher | Latest stable | Cluster Management | https://rancher.louielab.cc |

### IP Assignments

| IP | Service |
|----|---------|
| 192.168.50.50 | KubeVIP (K3s API) |
| 192.168.50.60 | Longhorn UI |
| 192.168.50.61 | ingress-nginx (Rancher, all ingresses) |
| 192.168.50.62-100 | Available for future LoadBalancer services |

### DNS Entries Required (pfSense)

| Hostname | IP |
|----------|-----|
| rancher.louielab.cc | 192.168.50.61 |

### Disabled K3s Components

- ServiceLB (replaced by MetalLB)
- Traefik (replaced by ingress-nginx)

---

## Web UIs

| Service | URL | Notes |
|---------|-----|-------|
| Rancher | https://rancher.louielab.cc | Cluster management |
| Longhorn | http://192.168.50.60 | Storage management |

---

## Namespaces

| Namespace | Contents |
|-----------|----------|
| kube-system | K3s core, KubeVIP, CoreDNS |
| cattle-system | Rancher |
| longhorn-system | Longhorn storage |
| ingress-nginx | NGINX ingress controller |
| cert-manager | Certificate management |
| metallb-system | MetalLB load balancer |

---

## Machines in the Lab

| Machine | Purpose | Notes |
|---------|---------|-------|
| Ansible | Ansible control machine | Has playbooks |
| Admin | kubectl/helm workstation | Primary management machine |
| Node-1/2/3 | K3s cluster nodes | 192.168.50.41-43 |

---

## Ansible Playbook

**File**: `k3s-ansible-complete.tar.gz`

### Quick Start
```bash
tar -xzvf k3s-ansible-complete.tar.gz
cd k3s-ansible-complete
ansible-galaxy collection install -r requirements.yml
ansible-playbook site.yml
```

### Reset Cluster
```bash
ansible-playbook reset.yml
# Type: yes-destroy-my-cluster
```

### Playbook Phases
1. prepare - System setup
2. k3s-init - First master
3. kubevip - API VIP
4. k3s-join - Additional masters
5. metallb - LoadBalancer
6. longhorn-prep - Disk setup
7. longhorn - Storage
8. ingress-nginx - Ingress controller
9. cert-manager - TLS certs
10. rancher - Cluster UI

---

## Common Commands

```bash
# Check cluster
kubectl get nodes
kubectl get pods -A
kubectl get svc -A
kubectl get ingress -A

# Check specific namespaces
kubectl get pods -n cattle-system      # Rancher
kubectl get pods -n longhorn-system    # Longhorn
kubectl get pods -n ingress-nginx      # Ingress
kubectl get pods -n cert-manager       # Certs
kubectl get pods -n metallb-system     # LoadBalancer

# SSH to nodes
ssh node-1
ssh node-2
ssh node-3

# Helm
helm list -A
helm repo update
```

---

## Adding New Ingress Services

1. Add DNS entry in pfSense → 192.168.50.61
2. Create Ingress with `ingressClassName: nginx`

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

---

## Known Issues & Solutions

| Issue | Solution |
|-------|----------|
| Proxmox interface is ens18, not eth0 | Set `node_interface: ens18` |
| K3s uses FQDN hostnames | Use `{{ hostname \| lower }}` in Ansible |
| /healthz returns 401 | Accept `status_code: [200, 401]` |
| cert-manager startupapicheck times out | Use `--set startupapicheck.enabled=false` |
| Ingress has no ADDRESS | Ensure `ingressClassName: nginx` is set |
| SSH ~ expansion fails | Use absolute paths like `/home/louie/.ssh/ansible` |

---

## Future Improvements

- Let's Encrypt with DNS challenge (Cloudflare)
- Prometheus/Grafana monitoring
- Velero backup

---

## Version History

- **v1.0** - Initial K3s HA cluster
- **v2.0** - Added ingress-nginx, cert-manager, Rancher (complete edition)
