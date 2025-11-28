# Grafana Stack

Monitoring stack with Prometheus, Loki, Grafana, Alertmanager, and cAdvisor.

## Services

| Service | Port | Description |
|---------|------|-------------|
| Grafana | 3000 | Dashboards and visualization |
| Prometheus | 9090 | Metrics collection and alerting |
| Loki | 3100 | Log aggregation |
| Alertmanager | 9093 | Alert routing and notifications |
| cAdvisor | 8080 | Container metrics |

## Configuration Files

```
config/
├── prometheus.yml        # Scrape targets and alerting config
├── alertmanager.yml.tmpl # Alert routing (template with env vars)
├── loki-config.yml       # Loki storage and retention settings
└── promtail-config.yml   # Log collection config (for reference)
```

Note: `promtail-config.yml` is included for reference. Promtail runs separately on each host that sends logs to Loki.

## Environment Variables

Create `.env` file at `/volume1/homelab/private/docker/grafana-stack/.env`:

```
SMTP_FROM=your-email@example.com
SMTP_USERNAME=your-email@example.com
SMTP_PASSWORD=your-app-password
ALERT_EMAIL=your-email@example.com
```

## Storage

All persistent data stored on Synology via NFS:

- `/volume1/Grafana-Prometheus` — Prometheus metrics
- `/volume1/Grafana-Loki` — Loki log data
- `/volume1/Grafana-Data` — Grafana dashboards and settings
- `/volume1/Grafana-Alertmanager` — Alertmanager state

## Deployment

```bash
docker compose --env-file /volume1/homelab/private/docker/grafana-stack/.env up -d
```

## Notes

- Alertmanager uses `envsubst` at startup to inject secrets into its config
- Loki retention is set to 7 days
- Prometheus scrape interval is 15 seconds
