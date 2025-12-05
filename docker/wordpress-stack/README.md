# WordPress

Self-hosted WordPress with MariaDB, Redis object cache, and phpMyAdmin.

- **Image:** [wordpress](https://hub.docker.com/_/wordpress)
- **Docs:** [Docker Hub](https://hub.docker.com/_/wordpress) | [WordPress.org](https://wordpress.org/documentation/)

## Services

| Service | Port | Description |
|---------|------|-------------|
| wordpress | 8080 | WordPress site |
| db | — | MariaDB database |
| redis | — | Object cache |
| phpmyadmin | 8090 | Database management UI |

## Environment Variables

Create a `wordpress.env` file with:

```env
# WordPress
WORDPRESS_DB_HOST=db
WORDPRESS_DB_USER=wp_user
WORDPRESS_DB_PASSWORD=
WORDPRESS_DB_NAME=wp_database

# MariaDB
MYSQL_DATABASE=wp_database
MYSQL_USER=wp_user
MYSQL_PASSWORD=
MYSQL_ROOT_PASSWORD=

# phpMyAdmin
PMA_HOST=db
```

## Storage

NFS volumes on Synology:

| Volume | Path | Description |
|--------|------|-------------|
| wp-site | `/mnt/ssd_pool/site` | WordPress files |
| wp-data | `/mnt/ssd_pool/data` | MariaDB data |

Redis data stored locally (ephemeral cache).

## Deployment

```bash
docker compose --env-file wordpress.env up -d
```

## Redis Object Cache

Install the [Redis Object Cache](https://wordpress.org/plugins/redis-cache/) plugin and configure:
- Host: `redis`
- Port: `6379`

## Notes

- MariaDB runs as UID/GID 3001 for NFS permission compatibility
- phpMyAdmin available for database administration
- Consider disabling phpMyAdmin in production
