# Paperless-ngx

Document management system with OCR and full-text search.

- **Image:** [paperless-ngx/paperless-ngx](https://github.com/paperless-ngx/paperless-ngx/pkgs/container/paperless-ngx)
- **Docs:** [GitHub](https://github.com/paperless-ngx/paperless-ngx) | [Documentation](https://docs.paperless-ngx.com)

## Services

| Service | Port | Description |
|---------|------|-------------|
| webserver | 8000 | Web UI and API |
| db | — | PostgreSQL database |
| broker | — | Redis message broker |
| gotenberg | — | PDF generation |
| tika | — | Document parsing |

## Environment Variables

Create a `docker-compose.env` file with:

```env
PAPERLESS_SECRET_KEY=
POSTGRES_PASSWORD=
PAPERLESS_ADMIN_USER=
PAPERLESS_ADMIN_PASSWORD=
```

See [Paperless-ngx configuration](https://docs.paperless-ngx.com/configuration/) for all options.

## Volumes

| Path | Description |
|------|-------------|
| `./data` | Application data |
| `./media` | Stored documents |
| `./export` | Export directory |
| `./consume` | Watched folder for auto-import |
| `./postgres` | PostgreSQL data |
| `./redis` | Redis persistence |

## Deployment

```bash
docker compose up -d
```

## Document Ingestion

Drop files into the `consume` directory for automatic import, or use:
- Web upload
- Email fetching
- Mobile app (requires API access)

## Notes

- Runs on Synology to leverage local storage
- Tika and Gotenberg enable advanced document processing
- Supports document tags, correspondents, and document types
