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

- `default_api_version`: Defaults to `3` unless overridden here. The service will
  still fall back across common Glances API versions automatically when polling.
- `refresh_seconds`: Controls the auto-refresh interval for the dashboard.
- `timeout_seconds`: HTTP timeout per request.
- `hosts`: List of monitored systems. Optional keys: `api_version`,
  `username`, and `password` for HTTP Basic Auth. Point each `url` at the
  Glances web server base (defaults to `http://<host>:61208`). You can also
  set `ha_port` (defaults to `8123`) or `ha_url` to control the link target
  when clicking a host name in the dashboard.

Restart the uvicorn process after editing `hosts.yaml` so the loader picks up
the changes. Consider adding a LaunchAgent for unattended startup once
validated.

### SSH shortcuts & remote actions

- Hosts with SSH enabled include an **SSH** shortcut button (via `ssh://` links)
  that macOS routes through `Terminal.app`. Override per-host behaviour by
  setting `ssh_user`, `ssh_host`, `ssh_port`, or `ssh_disabled` inside `hosts.yaml`.
- Remote reboot is exposed via `POST /hosts/{slug}/reboot` but is **disabled by
  default**. To enable it, set `remote_actions_enabled: true` and optionally
  configure `remote_actions_token` (sent as the `X-Auth-Token` header).

### Pending update counts

If your `coach_stats` command returns JSON that includes an `updates` object, the
dashboard surfaces those counts inside each host card. Example payload:

```json
{
  "coach": {"owner": "Coach 12"},
  "updates": {"apt_pending": 4, "docker_pending": 1}
}
```

The remote command can be anything—from `apt list --upgradable | tail -n +2 |
wc -l` to a Docker update checker—as long as it prints JSON with the keys
`apt_pending`/`apt` and `docker_pending`/`docker`. Edit `coach_stats.command`
in `hosts.yaml` (or per host) to run your script over SSH. Hosts without this
data simply omit the Updates line.

## Raspberry dashboard copy

A second copy of this project lives in `../raspberry_dashboard` and targets the
Raspberry Pi fleet (`raspberrypi1.local`–`raspberrypi8.local` plus
`raspberry-pdp.local`). Start it the same way, just `cd` into that directory and
pick a different uvicorn port (for example `--port 8081`) so both dashboards can
run simultaneously.
