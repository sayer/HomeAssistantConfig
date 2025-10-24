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
  local -a rows wired wifi others try_list

  if command -v ha >/dev/null 2>&1; then
    local network_json
    if network_json="$(ha network info 2>/dev/null)"; then
      local jq_rows
      if jq_rows="$(jq -r '
          .interfaces
          | to_entries[]
          | . as $e
          | ($e.value.ipv4.address // [])
          | map([ $e.key, (split("/")[0]) ] | @tsv)
          | .[]
        ' <<<"${network_json}" 2>/dev/null)"; then
        if [[ -n "${jq_rows}" ]]; then
          mapfile -t rows <<<"${jq_rows}"
        fi
      fi
    fi
  fi

  # Partition candidates: prefer wired (eth/en/ens/enp/eno) over wifi (wl/wlan)
  for row in "${rows[@]}"; do
    local iface ip
    iface="${row%%$'\t'*}"
    ip="${row#*$'\t'}"
    case "$iface" in
      eth*|en*|eno*|ens*|enp*) wired+=("$ip");;
      wl*|wlan*)               wifi+=("$ip");;
      *)                       others+=("$ip");;
    esac
  done

  try_list=( "${wired[@]}" "${wifi[@]}" "${others[@]}" )

  # Allow manual hosts to seed discovery if CLI isn't available
  if [[ -n "${HA_HOST:-}" ]]; then
    try_list+=("${HA_HOST}")
  fi
  if [[ -n "${HA_IP:-}" ]]; then
    try_list+=("${HA_IP}")
  fi

  # Check reachability: /api/ should return 200 without auth
  local candidate
  for candidate in "${try_list[@]}"; do
    [[ -z "$candidate" ]] && continue
    local url
    if [[ "$candidate" == http://* || "$candidate" == https://* ]]; then
      url="${candidate%/}"
    elif [[ "$candidate" == *:* ]]; then
      url="http://${candidate}"
    else
      url="http://${candidate}:${HA_PORT}"
    fi
    local code
    code="$(curl -m 2 -sS -o /dev/null -w '%{http_code}' "${url}/api/")" || true
    if [[ "$code" == "200" ]]; then
      echo "$url"
      return 0
    fi
  done

  # Fallbacks if discovery fails (mDNS, docker parent, loopback inside host)
  for candidate in \
      "http://host.docker.internal:${HA_PORT}" \
      "http://172.17.0.1:${HA_PORT}"
  do
    local code
    code="$(curl -m 2 -sS -o /dev/null -w '%{http_code}' "${candidate}/api/")" || true
    if [[ "$code" == "200" ]]; then
      echo "${candidate}"
      return 0
    fi
  done

  # Final fallbacks covering multicast DNS and localhost
  for candidate in \
      "http://homeassistant.local:${HA_PORT}" \
      "http://127.0.0.1:${HA_PORT}"
  do
    local code
    code="$(curl -m 2 -sS -o /dev/null -w '%{http_code}' "${candidate}/api/")" || true
    if [[ "$code" == "200" ]]; then
      echo "${candidate}"
      return 0
    fi
  done

  echo "Unable to discover a reachable Home Assistant URL via 'ha network info'." >&2
  exit 3
}

if [[ -n "${HA_URL:-}" ]]; then
  HA_URL="${HA_URL}"  # respect manual override as-is for now
else
  HA_URL="$(discover_ha_url)"
fi

if [[ "${HA_URL}" != http://* && "${HA_URL}" != https://* ]]; then
  if [[ "${HA_URL}" == *:* ]]; then
    HA_URL="http://${HA_URL}"
  else
    HA_URL="http://${HA_URL}:${HA_PORT}"
  fi
fi
HA_URL="${HA_URL%/}"

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
