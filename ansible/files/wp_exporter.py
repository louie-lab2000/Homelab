#!/usr/bin/env python3
"""
wp_exporter.py — Prometheus exporter for WordPress site health metrics.
Exposes WP-CLI data as Prometheus metrics on port 9105.

Metrics exported:
  wp_backup_last_success_timestamp_seconds  - Unix timestamp of last successful UpdraftPlus backup
  wp_backup_age_hours                       - Hours since last successful backup
  wp_backup_success                         - 1 if last backup was successful, 0 otherwise
  wp_plugin_updates_pending                 - Number of plugins with available updates
  wp_theme_updates_pending                  - Number of themes with available updates
  wp_core_update_available                  - 1 if a WordPress core update is available, 0 otherwise
  wp_exporter_scrape_success                - 1 if last scrape of WP-CLI succeeded, 0 otherwise
"""

import subprocess
import json
import time
import logging
from http.server import HTTPServer, BaseHTTPRequestHandler

# --- Configuration ---
WP_PATH        = "/var/www/wordpress"
WP_USER        = "www-data"
LISTEN_PORT    = 9105
SCRAPE_TIMEOUT = 25  # seconds per WP-CLI call

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger("wp_exporter")


def run_wpcli(args, timeout=SCRAPE_TIMEOUT):
    """Run a WP-CLI command as www-data and return stdout, or None on failure."""
    cmd = [
        "sudo", "-u", WP_USER,
        "wp", "--path=" + WP_PATH,
        "--allow-root",
        "--no-color",
    ] + args
    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=timeout,
        )
        if result.returncode != 0:
            log.warning("WP-CLI error for %s: %s", args, result.stderr.strip())
            return None
        return result.stdout.strip()
    except subprocess.TimeoutExpired:
        log.warning("WP-CLI timed out for %s", args)
        return None
    except Exception as e:
        log.error("WP-CLI exception for %s: %s", args, e)
        return None


def get_updraftplus_metrics():
    """
    Return (last_backup_timestamp, backup_success) by reading the
    updraft_last_backup option from the WordPress database.
    Returns (0, 0) on failure.
    """
    raw = run_wpcli(["option", "get", "updraft_last_backup", "--format=json"])
    if raw is None:
        return 0, 0
    try:
        data = json.loads(raw)
        # updraft_last_backup stores backup_time as a Unix timestamp
        # and success as 1 (int) on success
        last_backup = int(data.get("backup_time", 0))
        success = 1 if int(data.get("success", 0)) == 1 else 0
        return last_backup, success
    except (json.JSONDecodeError, ValueError, TypeError) as e:
        log.warning("Failed to parse updraft_last_backup option: %s", e)
        return 0, 0


def get_plugin_update_count():
    """Return number of plugins with available updates."""
    raw = run_wpcli(["plugin", "list", "--update=available", "--format=count"])
    if raw is None:
        return -1
    try:
        return int(raw)
    except ValueError:
        return 0


def get_theme_update_count():
    """Return number of themes with available updates."""
    raw = run_wpcli(["theme", "list", "--update=available", "--format=count"])
    if raw is None:
        return -1
    try:
        return int(raw)
    except ValueError:
        return 0


def get_core_update_available():
    """Return 1 if a WordPress core update is available, 0 if up to date, -1 on error."""
    raw = run_wpcli(["core", "check-update", "--format=json"])
    if raw is None:
        return -1
    try:
        data = json.loads(raw)
        return 1 if len(data) > 0 else 0
    except (json.JSONDecodeError, TypeError):
        # WP-CLI outputs plain text when already up to date — treat as no update
        return 0


def collect_metrics():
    """Collect all metrics and return a dict."""
    metrics = {
        "wp_backup_last_success_timestamp_seconds": 0,
        "wp_backup_age_hours": -1,
        "wp_backup_success": 0,
        "wp_plugin_updates_pending": -1,
        "wp_theme_updates_pending": -1,
        "wp_core_update_available": -1,
        "wp_exporter_scrape_success": 0,
    }

    try:
        last_ts, backup_ok = get_updraftplus_metrics()
        metrics["wp_backup_last_success_timestamp_seconds"] = last_ts
        metrics["wp_backup_success"] = backup_ok
        if last_ts > 0:
            age_hours = (time.time() - last_ts) / 3600
            metrics["wp_backup_age_hours"] = round(age_hours, 2)

        plugin_updates = get_plugin_update_count()
        metrics["wp_plugin_updates_pending"] = plugin_updates

        theme_updates = get_theme_update_count()
        metrics["wp_theme_updates_pending"] = theme_updates

        core_update = get_core_update_available()
        metrics["wp_core_update_available"] = core_update

        if not all(v == -1 for v in [plugin_updates, theme_updates, core_update]):
            metrics["wp_exporter_scrape_success"] = 1

    except Exception as e:
        log.error("Unexpected error during metric collection: %s", e)

    return metrics


def format_prometheus(metrics):
    """Format metrics dict as Prometheus text exposition format."""
    lines = []

    descs = {
        "wp_backup_last_success_timestamp_seconds": ("gauge", "Unix timestamp of the last successful UpdraftPlus backup"),
        "wp_backup_age_hours":                      ("gauge", "Hours elapsed since the last successful UpdraftPlus backup"),
        "wp_backup_success":                        ("gauge", "1 if the last UpdraftPlus backup completed successfully, 0 otherwise"),
        "wp_plugin_updates_pending":                ("gauge", "Number of WordPress plugins with available updates"),
        "wp_theme_updates_pending":                 ("gauge", "Number of WordPress themes with available updates"),
        "wp_core_update_available":                 ("gauge", "1 if a WordPress core update is available, 0 if up to date"),
        "wp_exporter_scrape_success":               ("gauge", "1 if the wp_exporter successfully scraped WP-CLI data, 0 otherwise"),
    }

    for name, value in metrics.items():
        mtype, help_text = descs.get(name, ("gauge", name))
        lines.append(f"# HELP {name} {help_text}")
        lines.append(f"# TYPE {name} {mtype}")
        lines.append(f"{name} {value}")

    return "\n".join(lines) + "\n"


class MetricsHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/metrics":
            start = time.time()
            metrics = collect_metrics()
            payload = format_prometheus(metrics).encode("utf-8")
            elapsed = time.time() - start
            log.info(
                "Scrape completed in %.2fs — backup_age=%.1fh plugin_updates=%s core_update=%s",
                elapsed,
                metrics["wp_backup_age_hours"],
                metrics["wp_plugin_updates_pending"],
                metrics["wp_core_update_available"],
            )
            self.send_response(200)
            self.send_header("Content-Type", "text/plain; version=0.0.4; charset=utf-8")
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)
        elif self.path == "/health":
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b"ok")
        else:
            self.send_response(404)
            self.end_headers()

    def log_message(self, format, *args):
        pass  # suppress default access log; we use our own


if __name__ == "__main__":
    log.info("wp_exporter starting on port %d", LISTEN_PORT)
    log.info("WordPress path: %s, running WP-CLI as: %s", WP_PATH, WP_USER)
    server = HTTPServer(("0.0.0.0", LISTEN_PORT), MetricsHandler)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        log.info("Shutting down")
