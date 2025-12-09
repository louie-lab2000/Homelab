# Homelab Monitoring Deployment

Ansible playbook to deploy promtail and prometheus-node-exporter across all homelab hosts.

## Files

```
deploy-monitoring/
├── deploy-monitoring.yml              # Main playbook
├── inventory                          # Host inventory (INI format)
├── ansible.cfg                        # Ansible configuration
├── templates/
│   ├── promtail-proxmox.yml.j2        # Proxmox hosts (journal + pve-firewall)
│   ├── promtail-docker.yml.j2         # Docker hosts (journal only)
│   ├── promtail-k3s.yml.j2            # K3s nodes (journal + k3s logs)
│   ├── promtail-web.yml.j2            # Web servers (journal + apache)
│   └── promtail-base.yml.j2           # Infra/other (journal only)
└── README.md
```

## Key Changes (December 2024)

- **Journal-based scraping**: Debian 13 and Proxmox are journal-only (no /var/log/syslog)
- **Group memberships**: Promtail added to `systemd-journal` and `adm` groups
- **Correct ownership**: Positions directory uses `nogroup` (not `promtail`)
- **Host-specific templates**: Different configs for proxmox, docker, k3s, web, and base

## Prerequisites

- Ansible installed on the control node (ansible.louielab.cc)
- SSH key at `~/.ssh/ansible`
- All target hosts reachable via SSH

## Usage

### Test connectivity first
```bash
ansible all -m ping
```

### Dry run (check mode)
```bash
ansible-playbook deploy-monitoring.yml --check
```

### Deploy to all hosts
```bash
ansible-playbook deploy-monitoring.yml
```

### Deploy to specific group
```bash
ansible-playbook deploy-monitoring.yml --limit proxmox
ansible-playbook deploy-monitoring.yml --limit docker_hosts
ansible-playbook deploy-monitoring.yml --limit web
ansible-playbook deploy-monitoring.yml --limit k3s
```

### Deploy to single host
```bash
ansible-playbook deploy-monitoring.yml --limit pve-01.louielab.cc
```

## Host Groups

| Group | Hosts | User | Template |
|-------|-------|------|----------|
| proxmox | pve-01, pve-02, pve-03, pve-10 | root | promtail-proxmox.yml.j2 |
| docker_hosts | docker-int, docker-edge | ansible | promtail-docker.yml.j2 |
| web | forum, blog2, www/test.leeannperugini.com | ansible | promtail-web.yml.j2 |
| k3s | node-1, node-2, node-3, admin | ansible | promtail-k3s.yml.j2 |
| infra | ansible.louielab.cc | ansible | promtail-base.yml.j2 |

**Excluded:**
- storage (TrueNAS SCALE) - handle via Docker containers
- backup51 - SSH may be disabled
- pve-04 - sandbox, usually offline

## What It Does

1. Adds the Grafana apt repository
2. Installs `promtail` and `prometheus-node-exporter`
3. Creates `/var/lib/promtail` directory with correct ownership (promtail:nogroup)
4. Adds promtail user to `systemd-journal` and `adm` groups
5. Deploys appropriate promtail config based on host group
6. Enables and starts both services
7. Verifies services are listening on expected ports

## Template Details

| Template | Scrapes |
|----------|---------|
| promtail-proxmox | journal, /var/log/*.log, /var/log/pve-firewall.log |
| promtail-docker | journal, /var/log/*.log |
| promtail-k3s | journal, /var/log/*.log, /var/log/k3s*.log |
| promtail-web | journal, /var/log/*.log, /var/log/apache2/*.log |
| promtail-base | journal, /var/log/*.log |

## Troubleshooting

### Check promtail targets on a host
```bash
curl localhost:9080/targets
```

### Check promtail logs
```bash
sudo journalctl -u promtail -f
```

### Check node_exporter status
```bash
sudo systemctl status prometheus-node-exporter
curl http://localhost:9100/metrics | head
```

### Verify promtail groups
```bash
id promtail
# Should show: groups=65534(nogroup),4(adm),xxx(systemd-journal)
```

### Verify logs in Grafana
In Grafana Explore with Loki datasource:
```
{job="systemd-journal"}
{host="pve-01"}
{job="apache", logtype="error"}
```

## Files to Delete

If upgrading from the old file-based config, delete these obsolete templates:
- `templates/promtail-config.yml.j2`
- `templates/promtail-config-docker.yml.j2`
