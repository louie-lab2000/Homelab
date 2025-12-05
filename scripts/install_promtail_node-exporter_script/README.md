# Install Promtail and Node Exporter

Installs Promtail (log shipper) and Prometheus Node Exporter on Debian hosts for centralized monitoring.

## What It Does

1. Adds Grafana APT repository
2. Installs Promtail from Grafana repo
3. Installs Node Exporter from Debian repo
4. Configures Promtail to ship logs to Loki
5. Enables and starts both services

## Requirements

- Debian 12+ (Bookworm or Trixie)
- sudo access
- Network access to Loki server

## Configuration

Edit the script to set your Loki URL:

```bash
LOKI_URL="http://192.168.51.20:3100/loki/api/v1/push"
```

## Usage

```bash
chmod +x install-promtail-node-exporter.sh
./install-promtail-node-exporter.sh
```

## What Gets Collected

**Promtail (Logs):**
- `/var/log/*.log` — System logs
- systemd journal — Service logs

**Node Exporter (Metrics):**
- CPU, memory, disk, network
- Available at `http://host:9100/metrics`

## Prometheus Integration

Add to your `prometheus.yml`:

```yaml
scrape_configs:
  - job_name: 'node'
    static_configs:
      - targets:
        - 'host1:9100'
        - 'host2:9100'
```

## Verification

```bash
systemctl status promtail
systemctl status prometheus-node-exporter
curl -s http://localhost:9100/metrics | head
```
