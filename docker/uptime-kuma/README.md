# Uptime Kuma

Self-hosted monitoring tool for tracking service availability.

- **Image:** [louislam/uptime-kuma](https://hub.docker.com/r/louislam/uptime-kuma)
- **Docs:** [GitHub](https://github.com/louislam/uptime-kuma)

## Services

| Service | Port | Description |
|---------|------|-------------|
| uptime-kuma | 3001 | Monitoring dashboard |

## Volumes

| Path | Description |
|------|-------------|
| `./data` | Configuration and monitoring data |

## Deployment

```bash
docker compose up -d
```

## Monitoring Types

- HTTP(S) / TCP / Ping / DNS
- Docker container status
- Steam game server
- MQTT
- PostgreSQL / MySQL / Redis

## Notifications

Supports 90+ notification services including:
- Email (SMTP)
- Slack / Discord / Telegram
- Pushover / Gotify
- Webhooks

## Notes

- Status pages can be shared publicly
- Supports maintenance windows
- Mobile-friendly responsive UI
