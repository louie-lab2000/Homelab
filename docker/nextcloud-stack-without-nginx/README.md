# Nextcloud (without Nginx)

Self-hosted file sync and collaboration platform. Use this version when you have a separate reverse proxy.

- **Image:** [nextcloud](https://hub.docker.com/_/nextcloud)
- **Docs:** [GitHub](https://github.com/nextcloud/docker) | [Documentation](https://docs.nextcloud.com)

## Services

| Service | Port | Description |
|---------|------|-------------|
| nextcloud | 9090 | Nextcloud web UI |
| nextclouddb | — | MariaDB database |
| collabora | 9980 | Collabora Online (document editing) |
| redis | — | Session cache and file locking |

## Environment Variables

Create a `nextcloud.env` file with:

```env
# Common
PUID=1000
PGID=1000
TZ=America/New_York

# Nextcloud
NEXTCLOUD_DATA_DIR=/mnt/ncdata
MYSQL_HOST=nextclouddb
REDIS_HOST=redis

# MariaDB
MYSQL_DATABASE=nextcloud
MYSQL_USER=nextcloud
MYSQL_PASSWORD=
MYSQL_ROOT_PASSWORD=

# Collabora
username=nextcloud
password=
domain=collabora.example.com
extra_params=--o:ssl.enable=true
```

## Networks

| Network | Purpose |
|---------|---------|
| cloud | Internal service communication |

## Storage

All volumes use NFS mounts to Synology:

| Volume | Path | Description |
|--------|------|-------------|
| html | `/volume1/nextcloud/html` | Nextcloud application |
| data | `/volume1/nextcloud/data` | User files |
| database | `/volume1/nextcloud/database` | MariaDB data |
| redis | `/volume1/nextcloud/redis` | Redis persistence |

## Deployment

```bash
docker compose --env-file nextcloud.env up -d
```

## Reverse Proxy Configuration

Configure your external reverse proxy to forward:
- `nextcloud.example.com` → `docker-host:9090`
- `collabora.example.com` → `docker-host:9980`

Collabora requires WebSocket support and specific headers.

## Maintenance

Common OCC commands (run from host):
```bash
docker exec --user www-data nextcloud php occ maintenance:mode --on
docker exec --user www-data nextcloud php occ maintenance:mode --off
docker exec --user www-data nextcloud php occ files:scan --all
```

## Notes

- Collabora requires SSL termination at the proxy
- Configure cron via system crontab for background jobs
