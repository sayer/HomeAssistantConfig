# Repository Guidelines

## Project Structure & Module Organization
- `configuration.template.yaml` is the source of truth; regenerate `configuration.yaml` via scripts only.
- Root YAML (`automations.yaml`, `scripts.yaml`, `scenes.yaml`, `shell_commands.yaml`) holds domain logic—group entries by alias prefix and bus zone.
- Media lives in `www/`; the tracked dashboard is `config/.storage/lovelace.dashboard_remote`. Treat `.storage/` as HA-managed state and keep `secrets.yaml`/`ssh_keys/` uncommitted.
- The RV-C bridge add-on resides at `../rvc2mqtt/rvc2mqtt`; reuse its command definitions when mapping shade or light codes.

## Build, Test, and Development Commands
- Run `./update_config.sh <MODEL_YEAR> [CONFIG_DIR]` on the Home Assistant appliance; it renders the template, backs up the prior file, and writes `configuration.yaml`.
- Use `./update_ha_config.sh` on that host (or via `./ha_multi_host.sh --host <pattern> update_ha_config`) to pull git, rebuild config, run `ha core check`, and restart core on success.
- For spot work, run `ha core check` until clean, then `ha core restart`; `ha_multi_host.sh --host <pattern> ping|docker` verifies SSH reachability and enters the `rvc2mqtt` container.

## Coding Style & Naming Conventions
- Prefer 2-space YAML indentation, tidy lists, and aligned nested keys.
- Automation aliases remain Title Case; entity IDs, scripts, and helpers stay lower_snake_case. Keep UI-issued numeric IDs intact.
- Add concise `#` comments for non-obvious logic, strip trailing whitespace, and mirror existing uppercase placeholder tokens.

## Testing Guidelines
- Execute `ha core check` on the remote system after each change and treat warnings as blockers.
- Rebuild `configuration.yaml` after template edits, then confirm rendered entities and secrets resolve correctly.
- Trigger new automations or scripts from Developer Tools → Run on the live instance and watch logs, notifications, or dashboards.

## Commit & Pull Request Guidelines
- Use short imperative commit subjects (~60 chars) similar to `Simplify shade group filtering`.
- Note affected domains and validation commands in commit bodies; ensure `git status` excludes secrets and backups.
- PRs should include a brief summary, linked issues, relevant screenshots, and the commands exercised.
- All Git pushes should be done as an actual PR. Use the "gh pr" command
- When opening new work, create a fresh branch and push via `gh pr create`; avoid reusing existing PRs for additional changes.

## Security & Configuration Tips
- Keep credentials behind `!secret` references and never inline tokens.
- Document new model-year placeholders inside `configuration.template.yaml` so scripts stay synchronized.
- Maintain the host list in `ha_multi_host.sh`, prefer Tailscale DNS names, and prune `/tmp/update_ha_config.log` after troubleshooting.
