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
├── loki-config.yml       # Loki storage and retention settings
└── promtail-config.yml   # Log collection config (for reference)
```

Note: `promtail-config.yml` is included for reference. Promtail runs separately on each host that sends logs to Loki.

## Private Configuration

Alertmanager config contains SMTP credentials and must be created manually in your private directory.

Create `~/homelab-private/docker/grafana-stack/alertmanager.yml` using this template:

```yaml
global:
  resolve_timeout: 5m
  smtp_smarthost: 'smtp.example.com:587'
  smtp_from: 'your-email@example.com'
  smtp_auth_username: 'your-email@example.com'
  smtp_auth_password: 'your-app-password'
  smtp_require_tls: true

route:
  receiver: email-team
  group_by: ['alertname']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 3h

receivers:
  - name: email-team
    email_configs:
      - to: 'your-email@example.com'
        send_resolved: true
```

## Storage

All persistent data stored on Synology via NFS:

- `/volume1/Grafana-Prometheus` — Prometheus metrics
- `/volume1/Grafana-Loki` — Loki log data
- `/volume1/Grafana-Data` — Grafana dashboards and settings
- `/volume1/Grafana-Alertmanager` — Alertmanager state

## Deployment

```bash
cd ~/homelab/docker/grafana-stack
docker compose up -d
```

## Notes

- Loki retention is set to 7 days
- Prometheus scrape interval is 15 seconds
