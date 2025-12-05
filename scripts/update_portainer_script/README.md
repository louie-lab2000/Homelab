# Update Portainer Script

Updates Portainer CE to the latest LTS release while preserving port mappings and data.

## What It Does

1. Detects current port mappings from running container
2. Stops and removes existing Portainer container
3. Pulls latest `portainer/portainer-ce:lts` image
4. Recreates container with same port mappings
5. Preserves `portainer_data` volume

## Requirements

- Docker installed
- Existing Portainer container named `portainer`
- `portainer_data` volume for persistence

## Usage

```bash
chmod +x update_portainer.sh
./update_portainer.sh
```

The script will prompt for confirmation before making changes.

## Default Ports

If no existing container is found:
- 8000 → 8000 (Edge agent)
- 9443 → 9443 (HTTPS UI)

## Notes

- Data is preserved in the `portainer_data` volume
- Edge agent connections may need to reconnect after update
- Check release notes for breaking changes before upgrading
