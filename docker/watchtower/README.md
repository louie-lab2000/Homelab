# Watchtower

Automatic Docker container updater.

- **Image:** [containrrr/watchtower](https://hub.docker.com/r/containrrr/watchtower)
- **Docs:** [GitHub](https://github.com/containrrr/watchtower) | [Documentation](https://containrrr.dev/watchtower)

## Services

| Service | Port | Description |
|---------|------|-------------|
| watchtower | — | Background update service |

## Volumes

| Path | Description |
|------|-------------|
| `/var/run/docker.sock` | Docker socket (required) |

## Environment Variables

Optional configuration:

```env
WATCHTOWER_SCHEDULE=0 0 4 * * *    # Cron schedule (4am daily)
WATCHTOWER_CLEANUP=true             # Remove old images
WATCHTOWER_INCLUDE_STOPPED=false    # Skip stopped containers
WATCHTOWER_NOTIFICATIONS=email      # Notification type
```

## Deployment

```bash
docker compose up -d
```

## Notification Options

- Email (SMTP)
- Slack
- Microsoft Teams
- Gotify
- Shoutrrr (generic webhook)

## Notes

- Monitors all running containers by default
- Use labels to include/exclude specific containers
- Can run once with `--run-once` flag for manual updates
