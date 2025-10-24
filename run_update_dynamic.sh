#!/usr/bin/env bash
set -euo pipefail

REMOTE_FILE="/config/.remote"
HA_PORT="${HA_PORT:-8123}"   # allow override via env or .remote
SCRIPT_ENTITY_DEFAULT="script.update_all_outdated"

# --- load per-instance secrets/overrides (token is required) ---
if [[ -r "$REMOTE_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$REMOTE_FILE"
fi
: "${HA_TOKEN:?Missing HA_TOKEN in /config/.remote}"
SCRIPT_ENTITY="${SCRIPT_ENTITY:-${SCRIPT_ENTITY_DEFAULT}}"

# --- pick the best reachable URL using `ha network info` ---
# Requires Supervisor CLI and jq (both available in SSH & Web Terminal add-on)
discover_ha_url() {
  # Grab interface -> address list; be liberal about schema
  # Output lines: "<ifname>\t<ipv4-address>"
  mapfile -t rows < <(
    ha network info \
    | jq -r '
        .interfaces
        | to_entries[]
        | . as $e
        | ($e.value.ipv4.address // [])
        | map([ $e.key, (split("/")[0]) ] | @tsv)
        | .[]
      '
  )

  # Partition candidates: prefer wired (eth/en/ens/enp/eno) over wifi (wl/wlan)
  wired=()
  wifi=()
  others=()
  for row in "${rows[@]}"; do
    iface="${row%%$'\t'*}"
    ip="${row#*$'\t'}"
    case "$iface" in
      eth*|en*|eno*|ens*|enp*) wired+=("$ip");;
      wl*|wlan*)               wifi+=("$ip");;
      *)                       others+=("$ip");;
    esac
  done

  # Check reachability: /api/ should return 200 without auth
  try_list=( "${wired[@]}" "${wifi[@]}" "${others[@]}" )
  for ip in "${try_list[@]}"; do
    code="$(curl -m 2 -sS -o /dev/null -w '%{http_code}' "http://${ip}:${HA_PORT}/api/")" || true
    if [[ "$code" == "200" ]]; then
      echo "http://${ip}:${HA_PORT}"
      return 0
    fi
  done

  # Fallbacks if discovery fails (mDNS, loopback inside host)
  for fallback in \
      "http://homeassistant.local:${HA_PORT}" \
      "http://127.0.0.1:${HA_PORT}"
  do
    code="$(curl -m 2 -sS -o /dev/null -w '%{http_code}' "${fallback}/api/")" || true
    [[ "$code" == "200" ]] && { echo "$fallback"; return 0; }
  done

  echo "Unable to discover a reachable Home Assistant URL via 'ha network info'." >&2
  exit 3
}

HA_URL="$(discover_ha_url)"

# --- trigger the update script via REST API ---
resp="$(curl -sS -X POST \
  -H "Authorization: Bearer ${HA_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{\"entity_id\":\"${SCRIPT_ENTITY}\"}" \
  "${HA_URL%/}/api/services/script/turn_on" \
  || true)"

if [[ "$resp" == "["*"]" ]]; then
  echo "Triggered ${SCRIPT_ENTITY} at ${HA_URL}"
else
  echo "API call may have failed. Response:" >&2
  echo "$resp" >&2
  exit 2
fi