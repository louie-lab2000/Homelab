# Daily APT Maintenance

Automated APT updates, cleanup, and conditional reboots for Debian/Proxmox hosts.

## Playbook

| Playbook | Description |
|----------|-------------|
| `apt-maintenance.yml` | Update packages, autoremove unused packages, reboot Proxmox hosts if required |

## Script

| Script | Description |
|--------|-------------|
| `apt-maintenance.sh` | Wrapper to run apt-maintenance.yml |

## Behavior

- All hosts: `apt update && apt dist-upgrade`, then `apt autoremove`
- Proxmox hosts only: Reboot if `/var/run/reboot-required` exists
- `proxmox_edge` group: Updates only, no automatic reboot (manual control)

## Inventory Groups

| Group | Reboot Behavior |
|-------|-----------------|
| `proxmox` | Conditional reboot |
| `proxmox_edge` | No automatic reboot |
| `webservers` | No reboot |
| `lxc_containers` | No reboot |

## Scheduling

Add to cron on your Ansible control node (pve-03):

```bash
30 3 * * * /home/louie/ansible/apt-maintenance/apt-maintenance.sh >> /home/louie/log/crontab.log 2>&1
```

## Usage

```bash
# Manual run
ansible-playbook apt-maintenance.yml

# Dry run (check mode)
ansible-playbook apt-maintenance.yml --check

# With the wrapper script
./apt-maintenance.sh
```
