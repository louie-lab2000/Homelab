# Upgrade Debian to Trixie

Ansible playbook to upgrade Debian 12 (Bookworm) to Debian 13 (Trixie).

## Warning

This is a major version upgrade. Test on non-critical systems first.

## Prerequisites

- Debian 12 (Bookworm) installed
- Current system fully updated
- Backups completed
- Console access available (in case SSH breaks)

## Playbook

| Playbook | Description |
|----------|-------------|
| `trixie.yml` | Full upgrade from Bookworm to Trixie |

## Role: upgrade_trixie

The role performs:
1. Updates `/etc/apt/sources.list` to Trixie
2. Runs `apt update`
3. Runs `apt full-upgrade`
4. Cleans up old packages
5. Reboots if kernel was upgraded

## Inventory

Update `inventory` with target hosts:

```ini
[upgrade]
host1 ansible_host=192.168.x.x
```

## Usage

```bash
# Dry run (check mode)
ansible-playbook -i inventory trixie.yml --check

# Execute upgrade
ansible-playbook -i inventory trixie.yml
```

## Post-Upgrade

1. Verify services are running
2. Check for held packages: `apt-mark showhold`
3. Review `/var/log/apt/history.log`
4. Update any third-party repositories
