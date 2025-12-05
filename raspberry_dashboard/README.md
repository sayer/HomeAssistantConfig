# Glances Fleet Dashboard

Lightweight FastAPI service that polls the Glances REST endpoints on the
Home Assistant hosts and renders a combined dashboard. The service runs on the
Mac monitoring station and only depends on HTTP access to each add-on.

## Quick start

1. Create a virtual environment on the Mac:
   ```bash
   python3 -m venv ~/.venvs/glances-dashboard
   ~/.venvs/glances-dashboard/bin/pip install fastapi uvicorn[standard] httpx pyyaml jinja2 rich
   ```
2. Edit `hosts.yaml` if the host list, API version, or refresh cadence should
   change. Each entry points to the Glances base URL (without `/api/*`).
3. Launch the dashboard:
   ```bash
   cd /Users/stephenayers/Documents/HomeAssistantConfig/glances_dashboard
   ~/.venvs/glances-dashboard/bin/uvicorn app:APP --host 0.0.0.0 --port 8080 --reload
   ```
4. Open `http://localhost:8080/` for the HTML view. `/text` returns a terminal
   summary, while `/status` exposes the raw aggregated JSON payload.

### Dashboard content

- CPU, load, and memory percentages plus used/total memory in friendly units.
- Wi-Fi signal strength/SSID via the `wifi` plugin.
- Private/public IP values from the `ip` plugin.
- Average filesystem usage percentage (across mounts reported by `fs`).

## Configuration

- `default_api_version`: Defaults to `3`, matching the add-on log output
  (`.../api/3/`). Override per host if some instances expose a different
  version.
- `refresh_seconds`: Controls the auto-refresh interval for the dashboard.
- `timeout_seconds`: HTTP timeout per request.
- `hosts`: List of monitored systems. Optional keys: `api_version`,
  `username`, and `password` for HTTP Basic Auth. You can also set
  `ha_port` (defaults to `8123`) or `ha_url` to control the link target
  when clicking a host name in the dashboard.

Restart the uvicorn process after editing `hosts.yaml` so the loader picks up
the changes. Consider adding a LaunchAgent for unattended startup once
validated.
