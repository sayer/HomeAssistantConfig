# Foretravel Home Assistant Configuration

This repository tracks the Home Assistant configuration for the Foretravel coach, including automations, scripts, Lovelace dashboards, and maintenance tooling.

## Getting Started
- Review [`AGENTS.md`](AGENTS.md) for contributor workflow, coding conventions, and deployment practices.
- Sensitive values stay in `secrets.yaml`; ensure you have the required environment-specific secrets before running update scripts.
- Regenerate `configuration.yaml` using the appliance-side scripts described in the guidelines to avoid template drift.

## Additional Resources
- Fleet maintenance commands: `ha_multi_host.sh` and `update_ha_config.sh`
- Dashboard source: `config/.storage/lovelace.dashboard_remote`
- RV-C bridge add-on: `../rvc2mqtt/rvc2mqtt`

For timezone setup instructions, see [`TIMEZONE_SETUP.md`](TIMEZONE_SETUP.md).

## Power Monitoring
- `sensor.ac_source` now keys off `sensor.ats_switch_position` and, when available, the inverter state to distinguish Shore, Generator, and Inverter feeds. `ATS_STATUS` advertises `source 1` (shore) and `source 2` (generator); inverter fallback only applies if `sensor.inverter_status` reports `invert`/`waiting to invert`.
- `sensor.ac_line_1_voltage`, `sensor.ac_line_1_current`, `sensor.ac_line_2_voltage`, and `sensor.ac_line_2_current` read the ATS output legs from `RVC/INVERTER_AC_STATUS_1`. Each sensor holds the last reported value so alternating leg updates from the bridge do not blank the companion leg.
- The Power dashboard now shows the active feed alongside line voltage/current so owners can validate the ATS view against the SilverLeaf panel.
