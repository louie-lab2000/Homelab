# Immich

Self-hosted photo and video management solution with AI-powered features.

- **Image:** [immich-app/immich-server](https://github.com/immich-app/immich/pkgs/container/immich-server)
- **Docs:** [GitHub](https://github.com/immich-app/immich) | [Documentation](https://immich.app/docs)

## Services

| Service | Port | Description |
|---------|------|-------------|
| immich-server | 2283 | Main web interface and API |
| immich-machine-learning | — | ML model inference for facial recognition, search |
| database | — | PostgreSQL with pgvector |
| redis | — | Cache and job queue |

## Environment Variables

Create a `.env` file with:

```env
DB_PASSWORD=
DB_USERNAME=
DB_DATABASE_NAME=
DB_DATA_LOCATION=
```

## Storage

| Volume | Type | Description |
|--------|------|-------------|
| photo | NFS | Photo/video uploads (Synology) |
| model-cache | Local | ML model cache |
| DB_DATA_LOCATION | Bind | PostgreSQL data |

## Hardware Acceleration

Uncomment the `extends` blocks in the compose file to enable:
- **Transcoding:** nvenc, quicksync, rkmpp, vaapi
- **ML inference:** armnn, cuda, rocm, openvino, rknn

## Deployment

```bash
docker compose up -d
```

## Notes

- Mobile apps available for iOS and Android
- Supports external libraries for existing photo collections
- Background jobs handle thumbnail generation, ML processing
