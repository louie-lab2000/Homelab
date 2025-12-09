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
grafana-stack/
├── docker-compose.yml    # Service definitions
├── prometheus.yml        # Scrape targets and alerting config
├── loki-config.yml       # Loki storage and retention settings
└── README.md
```

## Promtail

Promtail is deployed separately on each host via Ansible. See `ansible/deploy-monitoring/` for:
- Playbook to install promtail and node_exporter
- Host-specific templates (proxmox, docker, k3s, web, base)

Promtail uses **journal-based** scraping (Debian 13 and Proxmox are journal-only).

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

## cAdvisor on docker-edge

docker-edge runs cAdvisor standalone (not in compose). Deploy with:

```bash
docker run -d \
  --name cadvisor \
  --restart unless-stopped \
  -p 8082:8080 \
  -v /:/rootfs:ro \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  -v /sys:/sys:ro \
  -v /var/lib/docker/:/var/lib/docker:ro \
  gcr.io/cadvisor/cadvisor:v0.51.0
```

Note: Uses port 8082 to avoid conflict with other services.

## Notes

- Loki retention is set to 7 days
- Prometheus scrape interval is 15 seconds
- cAdvisor pinned to v0.51.0 (required for Docker API compatibility)
- cAdvisor mount is `/var/run/docker.sock` not `/var/run` (fixes container name labels)
