# LibreSpeed

Self-hosted speed test for measuring network performance.

- **Image:** [linuxserver/librespeed](https://hub.docker.com/r/linuxserver/librespeed)
- **Docs:** [GitHub](https://github.com/librespeed/speedtest)

## Services

| Service | Port | Description |
|---------|------|-------------|
| librespeed | 8080 | Speed test web UI |

## Environment Variables

Create a `.env` file with:

```env
PASSWORD=
```

## Volumes

| Path | Description |
|------|-------------|
| `/config` | Configuration and results database |

## Deployment

```bash
docker compose --env-file /path/to/.env up -d
```

## Notes

- Useful for testing internal network speeds between VLANs
- Results stored in SQLite when `CUSTOM_RESULTS=false`
