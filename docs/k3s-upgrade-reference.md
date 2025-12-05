# K3s HA Cluster Upgrade Reference

## Quick Reference

```bash
# 1. Edit versions in group_vars/all.yml
# 2. Run upgrade
ansible-playbook upgrade.yml

# Or upgrade specific components
ansible-playbook upgrade.yml --tags k3s
ansible-playbook upgrade.yml --tags rancher
```

---

## Step-by-Step Upgrade Process

### Step 1: Check for New Versions

| Component | Where to Check |
|-----------|----------------|
| K3s | https://github.com/k3s-io/k3s/releases |
| KubeVIP | https://github.com/kube-vip/kube-vip/releases |
| MetalLB | https://github.com/metallb/metallb/releases |
| Longhorn | https://github.com/longhorn/longhorn/releases |
| cert-manager | https://github.com/cert-manager/cert-manager/releases |
| Rancher | https://github.com/rancher/rancher/releases |

Or use Helm to check chart versions:
```bash
helm repo update
helm search repo jetstack/cert-manager --versions | head -10
helm search repo rancher-stable/rancher --versions | head -10
helm search repo ingress-nginx/ingress-nginx --versions | head -10
```

### Step 2: Update Versions in `group_vars/all.yml`

Edit the file and change the version numbers:

```yaml
# K3s version (leave empty for latest stable)
k3s_version: ""                  # Or pin: "v1.31.2+k3s1"

# KubeVIP
kubevip_version: "v1.0.2"        # Change to new version

# MetalLB
metallb_version: "v0.15.2"       # Change to new version

# Longhorn
longhorn_version: "v1.7.2"       # Change to new version

# cert-manager
cert_manager_version: "v1.17.4"  # Change to new version

# Rancher - uses latest from Helm chart (no version variable)
```

### Step 3: Run the Upgrade Playbook

**Upgrade everything at once:**
```bash
ansible-playbook upgrade.yml
```

**Or upgrade specific components:**
```bash
ansible-playbook upgrade.yml --tags k3s
ansible-playbook upgrade.yml --tags kubevip
ansible-playbook upgrade.yml --tags metallb
ansible-playbook upgrade.yml --tags longhorn
ansible-playbook upgrade.yml --tags ingress-nginx
ansible-playbook upgrade.yml --tags cert-manager
ansible-playbook upgrade.yml --tags rancher
```

**Upgrade multiple components:**
```bash
ansible-playbook upgrade.yml --tags cert-manager,rancher
```

### Step 4: Verify the Upgrade

```bash
ansible-playbook upgrade.yml --tags verify
```

Or manually check:
```bash
ssh node-1
kubectl get nodes
kubectl get pods -A
```

---

## Available Tags

| Tag | What It Does |
|-----|--------------|
| `backup` | Creates etcd snapshot before upgrade (runs automatically) |
| `k3s` | Rolling upgrade of K3s on all nodes (one at a time) |
| `kubevip` | Updates KubeVIP DaemonSet image |
| `metallb` | Downloads and applies new MetalLB manifest |
| `longhorn` | Downloads and applies new Longhorn manifest |
| `ingress-nginx` | Runs `helm upgrade` for ingress-nginx |
| `cert-manager` | Runs `helm upgrade` for cert-manager |
| `rancher` | Runs `helm upgrade` for Rancher |
| `verify` | Checks cluster health and displays all component versions |

---

## What is `--tags`?

`--tags` is an Ansible command-line option that runs only specific sections of a playbook.

Each section in `upgrade.yml` is labeled with a tag:

```yaml
- name: "Upgrade K3s"
  tags:
    - k3s          # <-- Tag name
  tasks:
    ...
```

When you run `--tags k3s`, Ansible skips everything except sections tagged `k3s`.

**Without tags:** Runs entire playbook (all components)
**With tags:** Runs only the specified sections

---

## Recommended Upgrade Order

For major version upgrades, follow this order:

| Order | Component | Notes |
|-------|-----------|-------|
| 1 | K3s | Foundation - upgrade first |
| 2 | KubeVIP | Quick, minimal impact |
| 3 | MetalLB | May briefly affect LoadBalancer IPs |
| 4 | cert-manager | Upgrade before Rancher (Rancher depends on it) |
| 5 | Rancher | Depends on cert-manager |
| 6 | Longhorn | Storage - be careful, avoid during heavy I/O |
| 7 | ingress-nginx | May briefly affect ingress traffic |

**For minor/patch updates:** Running `ansible-playbook upgrade.yml` all at once is usually fine.

---

## Backup and Rollback

### Automatic Backup

The upgrade playbook automatically creates an etcd snapshot before upgrading. Snapshots are stored on node-1 at:
```
/var/lib/rancher/k3s/server/db/snapshots/
```

### Manual Backup

```bash
ansible-playbook upgrade.yml --tags backup
```

### Rollback (If Something Goes Wrong)

1. Stop K3s on all nodes:
```bash
# On each node
sudo systemctl stop k3s
```

2. On node-1, restore from snapshot:
```bash
# List available snapshots
ls /var/lib/rancher/k3s/server/db/snapshots/

# Restore (replace <snapshot-name> with actual filename)
sudo k3s server \
  --cluster-reset \
  --cluster-reset-restore-path=/var/lib/rancher/k3s/server/db/snapshots/<snapshot-name>
```

3. Start K3s on node-1, then the other nodes.

---

## Dry Run (Check Mode)

Test what would happen without making changes:
```bash
ansible-playbook upgrade.yml --check
```

Note: This doesn't work perfectly for all tasks (especially shell commands), but gives you an idea of what will run.

---

## Troubleshooting

### Upgrade Stuck or Failed

1. Check which pods are having issues:
```bash
kubectl get pods -A | grep -v Running | grep -v Completed
```

2. Check pod logs:
```bash
kubectl logs -n <namespace> <pod-name>
```

3. Check node status:
```bash
kubectl get nodes
kubectl describe node <node-name>
```

### K3s Upgrade Failed on a Node

If K3s fails to restart on a node:
```bash
ssh <node>
sudo journalctl -xeu k3s.service --no-pager | tail -50
```

### Helm Upgrade Failed

Check Helm release status:
```bash
helm list -A
helm history <release-name> -n <namespace>
```

Rollback a Helm release:
```bash
helm rollback <release-name> <revision> -n <namespace>
```

---

## Current Versions (as of v2.2)

| Component | Version |
|-----------|---------|
| K3s | Latest stable |
| KubeVIP | v1.0.2 |
| MetalLB | v0.15.2 |
| Longhorn | v1.7.2 |
| cert-manager | v1.17.4 (LTS) |
| Rancher | Latest stable |
| ingress-nginx | Latest |

---

## Example: Full Upgrade Session

```bash
# Navigate to playbook directory
cd k3s-ansible-complete

# Check current versions
ansible-playbook upgrade.yml --tags verify

# Edit versions
nano group_vars/all.yml
# (change version numbers as needed)

# Run upgrade
ansible-playbook upgrade.yml

# Verify everything is healthy
ansible-playbook upgrade.yml --tags verify

# Check cluster
kubectl get nodes
kubectl get pods -A
```
