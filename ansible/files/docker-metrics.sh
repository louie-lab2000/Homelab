#!/bin/bash
# =============================================================================
# docker-metrics.sh - container running-state metrics via textfile collector
# Runs from a systemd timer every 30s on docker and docker-gpu.
# Output is picked up by Alloy's node exporter textfile collector and
# rides the existing remote_write pipeline to Prometheus.
#
# Why this exists (2026-07-14): Docker 29 with the containerd image
# store broke cAdvisor (no per-container series) and docker_exporter
# (stale API client, 400s). This uses the docker CLI, which cannot
# drift from the daemon it ships with.
# =============================================================================
set -euo pipefail

OUT_DIR=/var/lib/node_exporter/textfile
OUT="${OUT_DIR}/docker_containers.prom"
TMP="${OUT}.tmp"

mkdir -p "${OUT_DIR}"

{
  echo "# HELP docker_container_running 1 if the container state is running, 0 otherwise."
  echo "# TYPE docker_container_running gauge"
  docker ps -a --format '{{.Names}} {{.State}}' | while read -r name state; do
    if [ "${state}" = "running" ]; then v=1; else v=0; fi
    printf 'docker_container_running{name="%s"} %s\n' "${name}" "${v}"
  done
  echo "# HELP docker_containers_total Number of containers known to the daemon (any state)."
  echo "# TYPE docker_containers_total gauge"
  printf 'docker_containers_total %s\n' "$(docker ps -aq | wc -l)"
} > "${TMP}"

# Atomic move so the collector never reads a half-written file.
mv "${TMP}" "${OUT}"
