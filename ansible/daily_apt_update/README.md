# Daily APT Update

Automated APT updates and cleanup for Debian hosts.

## Playbooks

| Playbook | Description |
|----------|-------------|
| `apt-update.yml` | Run `apt update && apt upgrade` |
| `apt-autoremove.yml` | Clean up unused packages |

## Scripts

| Script | Description |
|--------|-------------|
| `ansible.sh` | Wrapper to run apt-update.yml |
| `autoremove.sh` | Wrapper to run apt-autoremove.yml |

## Inventory

Update `inventory` with your Debian hosts:

```ini
[debian]
host1 ansible_host=192.168.x.x
host2 ansible_host=192.168.x.x
```

## Scheduling

Add to cron on your Ansible control node:

```bash
# Daily updates at 3am
0 3 * * * /path/to/ansible.sh

# Weekly cleanup on Sundays at 4am
0 4 * * 0 /path/to/autoremove.sh
```

## Usage

```bash
# Manual run
ansible-playbook -i inventory apt-update.yml

# With the wrapper script
./ansible.sh
```
