# SearXNG

Privacy-respecting metasearch engine.

- **Image:** [searxng/searxng](https://hub.docker.com/r/searxng/searxng)
- **Docs:** [GitHub](https://github.com/searxng/searxng) | [Documentation](https://docs.searxng.org)

## Services

| Service | Port | Description |
|---------|------|-------------|
| searxng | 8081 | Search web UI |
| redis | — | Result caching (Valkey) |

## Networks

| Network | Purpose |
|---------|---------|
| searxng | Internal service communication |
| nginx | Reverse proxy access (external) |

## Configuration

Settings are configured in `settings.yml` mounted to `/etc/searxng`.

Key settings:
- Search engines enabled/disabled
- Result formatting
- Privacy options
- Rate limiting

## Volumes

| Volume | Description |
|--------|-------------|
| `/etc/searxng` | Configuration (bind mount) |
| `searxng-data` | Cache data |
| `valkey-data2` | Redis persistence |

## Deployment

```bash
docker compose up -d
```

## Notes

- Aggregates results from multiple search engines
- No tracking or profiling
- Customizable via settings.yml
