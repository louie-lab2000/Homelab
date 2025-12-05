#!/bin/bash
set -euo pipefail

# Prompt for sudo password upfront and cache credentials
sudo -v

LOKI_URL="http://192.168.51.20:3100/loki/api/v1/push"
HOSTNAME=$(hostname)

echo "=== Updating APT and installing prerequisites ==="
sudo apt update
sudo apt install -y curl gnupg ca-certificates

echo "=== Adding Grafana GPG key and repository ==="
sudo mkdir -p /usr/share/keyrings
curl -fsSL https://apt.grafana.com/gpg.key | sudo gpg --dearmor -o /usr/share/keyrings/grafana-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/grafana-archive-keyring.gpg] https://apt.grafana.com stable main" | \
  sudo tee /etc/apt/sources.list.d/grafana.list > /dev/null

echo "=== Updating APT cache ==="
sudo apt update

echo "=== Installing Promtail (Grafana repo) and Node Exporter (Debian repo) ==="
sudo apt install -y promtail prometheus-node-exporter

echo "=== Creating Promtail configuration ==="
sudo tee /etc/promtail/config.yml > /dev/null <<EOF
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /var/lib/promtail/positions.yaml

clients:
  - url: ${LOKI_URL}

scrape_configs:
  - job_name: system
    static_configs:
      - targets:
          - localhost
        labels:
          job: varlogs
          host: ${HOSTNAME}
          __path__: /var/log/*.log

  - job_name: journal
    journal:
      max_age: 12h
      labels:
        job: systemd-journal
        host: ${HOSTNAME}
    relabel_configs:
      - source_labels: ['__journal__systemd_unit']
        target_label: 'unit'
EOF

echo "=== Ensuring promtail user can read logs ==="
sudo usermod -aG adm promtail

echo "=== Enabling and starting services ==="
sudo systemctl enable promtail prometheus-node-exporter
sudo systemctl restart promtail prometheus-node-exporter

echo "=== Waiting for services to stabilize ==="
sleep 3

echo "=== Verifying services ==="
if ! systemctl is-active --quiet promtail; then
  echo "❌ Promtail failed to start"
  sudo journalctl -u promtail --no-pager -n 20
  exit 1
fi
echo "✅ Promtail is running"

if ! systemctl is-active --quiet prometheus-node-exporter; then
  echo "❌ Node Exporter failed to start"
  sudo journalctl -u prometheus-node-exporter --no-pager -n 20
  exit 1
fi
echo "✅ Node Exporter is running"

echo
echo "=== Installation complete ==="
echo "Promtail sending to: ${LOKI_URL}"
echo "Node Exporter metrics: http://${HOSTNAME}:9100/metrics"
