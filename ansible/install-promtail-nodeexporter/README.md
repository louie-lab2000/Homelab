# Homelab Monitoring Deployment

Ansible playbook to deploy promtail and prometheus-node-exporter across all homelab hosts.

## Files

```
ansible/
├── deploy-monitoring.yml          # Main playbook
├── inventory                      # Host inventory (INI format)
├── templates/
│   ├── promtail-config.yml.j2         # Config for non-Docker hosts
│   └── promtail-config-docker.yml.j2  # Config for Docker hosts
└── README.md
```

## Prerequisites

- Ansible installed on the control node (192.168.10.10)
- SSH key at `/home/louie/.ssh/ansible`
- Existing `ansible.cfg` in `/home/louie/ansible/`

## Usage

### Test connectivity first
```bash
ansible -i inventory all -m ping
```

### Dry run (check mode)
```bash
ansible-playbook -i inventory deploy-monitoring.yml --check
```

### Deploy to all hosts
```bash
ansible-playbook -i inventory deploy-monitoring.yml
```

### Deploy to specific group
```bash
ansible-playbook -i inventory deploy-monitoring.yml --limit proxmox
ansible-playbook -i inventory deploy-monitoring.yml --limit docker_hosts
ansible-playbook -i inventory deploy-monitoring.yml --limit web
```

### Deploy to single host
```bash
ansible-playbook -i inventory deploy-monitoring.yml --limit pve-01.louielab.cc
```

## Host Groups

| Group | Hosts | User | Notes |
|-------|-------|------|-------|
| proxmox | pve-01, pve-02, pve-03, pve-10 | root | Proxmox hypervisors |
| docker_hosts | docker-int, docker-edge | ansible | Gets Docker log scraping |
| web | forum, blog2, www.leeannperugini.com, test.leeannperugini.com | ansible | WordPress/Discourse VMs |
| k3s | node-1, node-2, node-3, admin | ansible | K3s HA cluster |
| infra | localhost | ansible | Ansible control node (local) |

**Excluded:**
- storage (TrueNAS SCALE) - handle via Docker containers
- backup51 - SSH may be disabled
- pve-04 - sandbox, usually offline

## What It Does

1. Adds the Grafana apt repository
2. Installs `promtail` and `prometheus-node-exporter`
3. Creates `/var/lib/promtail` directory for positions file
4. Deploys appropriate promtail config:
   - Docker hosts get config with Docker log scraping
   - Other hosts get system logs only
5. Enables and starts both services
6. Verifies services are listening on expected ports

## Customization

Edit `inventory.yml` to:
- Add/remove hosts
- Change `ansible_user` if not using `louie`
- Change `loki_url` if Loki moves

## Troubleshooting

### Check promtail status on a host
```bash
sudo systemctl status promtail
sudo journalctl -u promtail -f
```

### Check node_exporter status
```bash
sudo systemctl status prometheus-node-exporter
curl http://localhost:9100/metrics | head
```

### Verify promtail is sending to Loki
```bash
curl -s http://localhost:9080/metrics | grep promtail_sent
```
