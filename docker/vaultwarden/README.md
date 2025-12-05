# Vaultwarden

Bitwarden-compatible password manager server.

- **Image:** [vaultwarden/server](https://hub.docker.com/r/vaultwarden/server)
- **Docs:** [GitHub](https://github.com/dani-garcia/vaultwarden) | [Wiki](https://github.com/dani-garcia/vaultwarden/wiki)

## Services

| Service | Port | Description |
|---------|------|-------------|
| vaultwarden | 9081 | Web vault and API |

## Environment Variables

Create a `.env` file with:

```env
ADMIN_TOKEN=
```

Generate a secure token:
```bash
openssl rand -base64 48
```

## Networks

Requires external network:
- `nginx-edge_default` — reverse proxy access

## Storage

| Volume | Type | Description |
|--------|------|-------------|
| vaultwarden | NFS | Data directory (Synology) |

## Health Check

Built-in health check at `/alive` endpoint ensures container restarts on failure.

## Deployment

```bash
docker compose --env-file /path/to/.env up -d
```

## Admin Panel

Access at `https://your-domain/admin` using the `ADMIN_TOKEN`.

Disable registrations after creating accounts:
```env
SIGNUPS_ALLOWED=false
```

## Notes

- Uses official Bitwarden clients (browser, mobile, desktop)
- Admin panel for user management and server settings
- Supports hardware keys (WebAuthn/FIDO2)
- NFS mount includes `soft,timeo=30,retrans=3` for reliability after reboots
