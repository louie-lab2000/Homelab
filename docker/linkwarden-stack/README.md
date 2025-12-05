# Linkwarden

Self-hosted bookmark manager with full-text search and archiving.

- **Image:** [linkwarden/linkwarden](https://github.com/linkwarden/linkwarden/pkgs/container/linkwarden)
- **Docs:** [GitHub](https://github.com/linkwarden/linkwarden) | [Documentation](https://docs.linkwarden.app)

## Services

| Service | Port | Description |
|---------|------|-------------|
| linkwarden | 3001 | Web UI and API |
| postgres | — | PostgreSQL database |
| meilisearch | — | Full-text search engine |

## Environment Variables

Create a `.env` file with:

```env
POSTGRES_PASSWORD=
NEXTAUTH_SECRET=
MEILI_MASTER_KEY=
```

## Networks

Requires external networks:
- `linkwarden` — internal service communication
- `nginx` — reverse proxy access

Create before deployment:
```bash
docker network create linkwarden
docker network create nginx
```

## Storage

All volumes use NFS mounts to Synology:

| Volume | Path | Description |
|--------|------|-------------|
| pgdata | `/volume1/linkwarden/pgdata` | PostgreSQL data |
| data | `/volume1/linkwarden/data` | Linkwarden data and archives |
| meili_data | `/volume1/linkwarden/meili_data` | Search index |

## Deployment

```bash
docker compose --env-file /path/to/.env up -d
```

## Notes

- Browser extension available for quick saving
- Supports automatic webpage archiving
- Tags and collections for organization
