# Nginx Proxy Manager

Web-based reverse proxy manager with Let's Encrypt SSL support.

- **Image:** [jc21/nginx-proxy-manager](https://hub.docker.com/r/jc21/nginx-proxy-manager)
- **Docs:** [GitHub](https://github.com/NginxProxyManager/nginx-proxy-manager) | [Documentation](https://nginxproxymanager.com/guide)

## Services

| Service | Port | Description |
|---------|------|-------------|
| nginx-edge | 80 | HTTP |
| nginx-edge | 81 | Admin UI |
| nginx-edge | 443 | HTTPS |

## Volumes

| Path | Description |
|------|-------------|
| `/data` | Configuration and database |
| `/etc/letsencrypt` | SSL certificates |

## Deployment

```bash
docker compose up -d
```

## Initial Setup

1. Access admin UI at `http://host:81`
2. Default credentials: `admin@example.com` / `changeme`
3. Change password immediately after first login

## Notes

- Supports automatic Let's Encrypt certificate renewal
- Access lists for IP-based restrictions
- Stream proxying for TCP/UDP services
