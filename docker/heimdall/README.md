# Heimdall

Application dashboard for organizing and launching web services.

- **Image:** [linuxserver/heimdall](https://hub.docker.com/r/linuxserver/heimdall)
- **Docs:** [GitHub](https://github.com/linuxserver/Heimdall)

## Services

| Service | Port | Description |
|---------|------|-------------|
| Heimdall | 80, 443 | Dashboard UI |

## Volumes

| Path | Description |
|------|-------------|
| `/config` | Configuration and database |

## Deployment

```bash
docker compose up -d
```
