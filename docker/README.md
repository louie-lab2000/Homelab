# Docker Compose Stacks

Each subdirectory contains a sanitized `docker-compose.yml` and service-specific `README.md`.

## Adding a New Service

1. Create a directory named after the service
2. Add `docker-compose.yml` with `${VARIABLE}` references for secrets
3. Add `README.md` documenting required environment variables
4. Create corresponding `.env` file in `/volume1/homelab/private/docker/<service>/`

## Deployment

```bash
docker compose --env-file /path/to/private/.env up -d
```
