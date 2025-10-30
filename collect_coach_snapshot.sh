#!/usr/bin/env bash
set -euo pipefail

# Mirrors the authentication and discovery logic used by run_update_dynamic.sh
# to call script.collect_coach_snapshot and emit the JSON payload.
# 

debug() {
  if [[ "${COLLECT_DEBUG:-0}" == "1" ]]; then
    echo "[collect] $*" >&2
  fi
}

REMOTE_FILE=""
HA_PORT="${HA_PORT:-8123}"

for candidate in "/root/config/.remote" "/config/.remote"; do
  if [[ -z "$REMOTE_FILE" && -r "$candidate" ]]; then
    REMOTE_FILE="$candidate"
  fi
done

if [[ -n "$REMOTE_FILE" ]]; then
  debug "Using credential file: $REMOTE_FILE"
  # shellcheck disable=SC1090
  source "$REMOTE_FILE"
else
  echo "collect_coach_snapshot: unable to locate .remote credentials (checked /root/config/.remote and /config/.remote)" >&2
  exit 4
fi

if [[ -z "${HA_TOKEN:-}" ]]; then
  echo "collect_coach_snapshot: HA_TOKEN missing in $REMOTE_FILE" >&2
  exit 4
fi

is_http_reachable() {
  case "$1" in
    200|201|202|204|301|302|307|308|401|403) return 0 ;;
    *) return 1 ;;
  esac
}

discover_ha_url() {
  local -a rows=() wired=() wifi=() others=() try_list=()

  if command -v ha >/dev/null 2>&1; then
    local ha_output="" ha_cmd
    for ha_cmd in \
        "ha network info --raw-json" \
        "ha network info --json" \
        "ha network info"; do
      if ha_output="$(${ha_cmd} 2>/dev/null)"; then
        debug "Fetched network info via '${ha_cmd}'"
        if [[ -n "${ha_output}" ]]; then
          break
        fi
      fi
      ha_output=""
    done

    if [[ -n "${ha_output}" ]]; then
      if command -v jq >/dev/null 2>&1 && [[ "${ha_output:0:1}" =~ [\{\[] ]]; then
        local jq_rows
        jq_rows="$(jq -r '
            .interfaces
            | to_entries[]
            | . as $e
            | ($e.value.ipv4.address // [])
            | map([ $e.key, (split("/")[0]) ] | @tsv)
            | .[]
          ' <<<"${ha_output}" 2>/dev/null)" || true
        if [[ -n "${jq_rows}" ]]; then
          mapfile -t rows <<<"${jq_rows}"
          debug "Extracted ${#rows[@]} interface candidates via jq"
        fi
      fi

      if [[ "${#rows[@]}" -eq 0 ]]; then
        local iface="" section="" collecting=0 line trimmed ip
        while IFS= read -r line; do
          trimmed="${line}"
          if [[ "${trimmed}" =~ ^[[:space:]]*(.*)$ ]]; then
            trimmed="${BASH_REMATCH[1]}"
          fi
          case "${trimmed}" in
            interface:*)
              iface="${trimmed#interface: }"
              ;;
            ipv4:*)
              section="ipv4"
              collecting=0
              ;;
            ipv6:*)
              section="ipv6"
              collecting=0
              ;;
            address:*)
              if [[ "${section}" == "ipv4" ]]; then
                collecting=1
              else
                collecting=0
              fi
              ;;
            -*)
              if (( collecting )) && [[ -n "${iface}" ]]; then
                ip="${trimmed#- }"
                ip="${ip%%/*}"
                if [[ -n "${ip}" ]]; then
                  rows+=("${iface}"$'\t'"${ip}")
                fi
              fi
              ;;
            *)
              ;;
          esac
        done <<<"${ha_output}"
        debug "Extracted ${#rows[@]} interface candidates via YAML parse"
      fi
    fi
  fi

  local row iface ip
  for row in "${rows[@]}"; do
    iface="${row%%$'\t'*}"
    ip="${row#*$'\t'}"
    case "$iface" in
      eth*|en*|eno*|ens*|enp*) wired+=("$ip");;
      wl*|wlan*)               wifi+=("$ip");;
      *)                       others+=("$ip");;
    esac
  done

  try_list=("${wired[@]}" "${wifi[@]}" "${others[@]}")
  try_list+=(
    "homeassistant.local"
    "127.0.0.1"
    "supervisor"
    "host.docker.internal"
    "172.30.32.1"
    "172.30.33.1"
    "172.17.0.1"
  )

  local candidate url code
  for candidate in "${try_list[@]}"; do
    [[ -n "$candidate" ]] || continue

    if [[ "$candidate" == http://* || "$candidate" == https://* ]]; then
      url="${candidate}"
    else
      url="http://${candidate}:${HA_PORT}"
    fi

    code="$(curl -m 2 -sS -o /dev/null -w '%{http_code}' "${url}/api/" 2>/dev/null)" || true
    debug "Probed ${url}/api -> status ${code}"
    if is_http_reachable "$code"; then
      debug "Discovered reachable HA URL ${url} (status ${code})"
      echo "$url"
      return 0
    fi
  done

  echo "Unable to discover a reachable Home Assistant URL via 'ha network info'." >&2
  exit 3
}

if [[ -n "${HA_URL:-}" ]]; then
  debug "Using HA_URL from environment: ${HA_URL}"
  HA_URL="${HA_URL}"
else
  HA_URL="$(discover_ha_url)"
  debug "Discovered HA_URL: ${HA_URL:-<none>}"
fi

if [[ "${HA_URL}" != http://* && "${HA_URL}" != https://* ]]; then
  if [[ "${HA_URL}" == *:* ]]; then
    HA_URL="http://${HA_URL}"
  else
    HA_URL="http://${HA_URL}:${HA_PORT}"
  fi
fi
HA_URL="${HA_URL%/}"
debug "Normalized HA_URL: ${HA_URL}"

tmp_body="$(mktemp)"
trap 'rm -f "$tmp_body"' EXIT

TEMPLATE=$(cat <<'EOF'
{% set invalid = ['unknown', 'unavailable', '', none, 'None'] %}
{% set zone_sensors = [
  'sensor.thermostat1_zone_temperature',
  'sensor.thermostat2_zone_temperature',
  'sensor.thermostat3_zone_temperature',
  'sensor.thermostat4_zone_temperature'
] %}
{% set temps = namespace(values=[]) %}
{% for entity_id in zone_sensors %}
  {% set value = states(entity_id) %}
  {% if value not in invalid %}
    {% set temps.values = temps.values + [value | float] %}
  {% endif %}
{% endfor %}
{% set interior_temp = (temps.values | average) if temps.values | length > 0 else none %}
{% set pending = namespace(items=[]) %}
{% for item in states.update %}
  {% if item.state == 'on' %}
    {% set pending.items = pending.items + [{
      "entity_id": item.entity_id,
      "name": item.name,
      "installed": item.attributes.installed_version | default(none),
      "latest": item.attributes.latest_version | default(none),
      "skipped": item.attributes.skipped_version | default(none)
    }] %}
  {% endif %}
{% endfor %}
{% set coach_number_raw = states('input_number.coach_number') %}
{% set coach_year_raw = states('input_number.model_year') %}
{% set owner_raw = states('input_text.owner_name') %}
{% set chassis_voltage_raw = states('sensor.chassis_battery') %}
{% set house_voltage_raw = states('sensor.house_battery_voltage') %}
{% set fresh_water_raw = states('sensor.fresh_water') %}
{% set black_tank_raw = states('sensor.black_tank') %}
{% set instance_name = state_attr('zone.home', 'friendly_name') | default('Home', true) %}
{% if instance_name in invalid %}
  {% set instance_name = states('sensor.location_name') %}
{% endif %}
{% if instance_name in invalid %}
  {% set instance_name = 'Home Assistant' %}
{% endif %}
{% set version_val = state_attr('update.home_assistant_core_update', 'installed_version') %}
{% if version_val in invalid %}
  {% set version_val = state_attr('update.home_assistant_core_update', 'current_version') %}
{% endif %}
{% if version_val in invalid %}
  {% set version_val = state_attr('update.home_assistant_core_update', 'latest_version') %}
{% endif %}
{{
  {
    "timestamp": now().isoformat(),
    "instance": instance_name,
    "coach": {
      "number": (coach_number_raw | int) if coach_number_raw not in invalid else none,
      "year": (coach_year_raw | int) if coach_year_raw not in invalid else none,
      "owner": owner_raw if owner_raw not in invalid else none
    },
    "ha": {
      "version": version_val if version_val not in invalid else none,
      "pending_update_count": pending.items | length,
      "pending_updates": pending.items
    },
    "metrics": {
      "chassis_battery_voltage": (chassis_voltage_raw | float) if chassis_voltage_raw not in invalid else none,
      "house_battery_voltage": (house_voltage_raw | float) if house_voltage_raw not in invalid else none,
      "interior_temperature": (interior_temp | round(1)) if interior_temp is not none else none,
      "fresh_water_level": (fresh_water_raw | float) if fresh_water_raw not in invalid else none,
      "black_tank_level": (black_tank_raw | float) if black_tank_raw not in invalid else none
    }
  } | to_json
}}
EOF
)

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required for collect_coach_snapshot.sh" >&2
  exit 5
fi

template_json=$(printf '%s' "$TEMPLATE" | jq -Rs .)
debug "Submitting template to ${HA_URL}/api/template"

http_code="$(curl -sS -o "$tmp_body" -w '%{http_code}' \
  -X POST \
  -H "Authorization: Bearer ${HA_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{\"template\": ${template_json}}" \
  "${HA_URL}/api/template" \
  || true)"
debug "Template HTTP status: ${http_code}"

if ! is_http_reachable "$http_code"; then
  debug "Template call failed; body: $(cat "$tmp_body")"
  cat "$tmp_body" >&2
  echo "Template request failed with status ${http_code}" >&2
  exit 2
fi

body="$(cat "$tmp_body")"
debug "Template response: ${body}"

payload=$(jq -r '.result' <<<"$body" 2>/dev/null || true)
debug "Extracted payload: ${payload}"

if [[ -z "$payload" || "$payload" == "null" ]]; then
  debug "Payload extraction failed; emitting raw body"
  printf '%s\n' "$body"
  exit 5
fi

printf '%s\n' "$payload" | jq -c .
