# Glances Fleet Dashboard

Lightweight FastAPI service that polls the Glances REST endpoints on
Raspberry Pi hosts and renders a combined dashboard. The service runs on the
Mac monitoring station and only depends on HTTP access to each Glances instance.

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
   cd /Users/stephenayers/Documents/HomeAssistantConfig/raspberry_dashboard
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
  `username`, and `password` for HTTP Basic Auth. You can also set per-host
  SSH fields (`ssh_user`, `ssh_host`, `ssh_port`, `ssh_disabled`) to control
  how terminal links behave.

Restart the uvicorn process after editing `hosts.yaml` so the loader picks up
the changes. Consider adding a LaunchAgent for unattended startup once
validated.

### Remote actions

- Clicking a host title launches `Terminal.app` and opens an SSH session as the
  `sayer` user (via `ssh://` links). Override per-host behaviour by setting
  `ssh_user`, `ssh_host`, `ssh_port`, or `ssh_disabled` inside `hosts.yaml`.
- Each card includes a **Run updates** button that executes, on the remote host,
  `sudo apt update && sudo apt dist-upgrade -y && sudo apt autoremove -y &&
  sudo apt clean`. Set `update_command` per host (or globally), or add
  `update_disabled: true` to hide the button.
- A **Restart** button on each card calls `/hosts/<slug>/restart`, restarting
  the Glances service by default. Override per host with `restart_command`
  or disable with `restart_disabled: true`.
- A **Reboot** button on each card calls `/hosts/<slug>/reboot`, which SSHes in
  and runs `sudo reboot` by default. Override per host with `reboot_command`.
- The app maintains SSH host aliases in `~/.ssh/raspberry-dashboard` (and adds
  `Include ~/.ssh/raspberry-dashboard` to `~/.ssh/config` if needed) so the
  update buttons can target `ssh://raspberry-update-…` URLs automatically.
- A **Run all updates** button in the header calls `/updates`, which checks every
  online host and runs the update command in parallel via SSH. Status text shows
  how many hosts succeeded or failed.
