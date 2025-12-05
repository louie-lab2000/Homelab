# Ansible

Playbooks and roles for homelab automation.

## Contents

| Directory | Description |
|-----------|-------------|
| `k3s-ansible-complete/` | Full K3s HA cluster deployment with Rancher, Longhorn, MetalLB |
| `daily_apt_update/` | Scheduled APT updates across all Debian hosts |
| `update_debian_to_trixie/` | Debian 12 → 13 (Trixie) upgrade playbook |

## Requirements

- Ansible 2.15+
- SSH key access to target hosts
- Passwordless sudo on targets

## Quick Start

```bash
# Install collections (for k3s-ansible-complete)
ansible-galaxy collection install -r k3s-ansible-complete/requirements.yml

# Test connectivity
ansible -i inventory all -m ping

# Run a playbook
ansible-playbook -i inventory playbook.yml
```

## Inventory

Each subdirectory maintains its own inventory. Update host IPs and credentials as needed.
