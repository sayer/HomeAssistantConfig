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
# Enable discovery debug logs by exporting HA_DISCOVER_DEBUG=1
debug() {
  if [[ "${HA_DISCOVER_DEBUG:-0}" == "1" ]]; then
    echo "[discover] $*" >&2
  fi
}

is_http_reachable() {
  case "$1" in
    200|401|403|301|302|307|308) return 0 ;;
    *) return 1 ;;
  esac
}

# Prefers Supervisor CLI JSON via jq, but falls back to parsing YAML output
discover_ha_url() {
  local -a rows=() wired=() wifi=() others=() try_list=()

  if command -v ha >/dev/null 2>&1; then
    local ha_output=""
    local ha_cmd
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
              ;;  # ignore other fields
          esac
        done <<<"${ha_output}"
        debug "Extracted ${#rows[@]} interface candidates via YAML parse"
      fi
    fi
  fi

  # Partition candidates: prefer wired (eth/en/ens/enp/eno) over wifi (wl/wlan)
  local row
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
  debug "Wired=${wired[*]} Wifi=${wifi[*]} Others=${others[*]}"

  try_list=( "${wired[@]}" "${wifi[@]}" "${others[@]}" )

  if [[ "${#try_list[@]}" -eq 0 ]]; then
    local host_ips_raw
    if host_ips_raw="$(hostname -I 2>/dev/null)"; then
      read -ra try_list <<<"${host_ips_raw}"
      debug "Seeded try_list from hostname -I: ${try_list[*]}"
    fi
    if [[ "${#try_list[@]}" -eq 0 ]] && command -v ip >/dev/null 2>&1; then
      mapfile -t try_list < <(ip -o -4 addr show scope global | awk '{print $4}' | cut -d/ -f1)
      debug "Seeded try_list from ip addr: ${try_list[*]}"
    fi
  fi

  # Allow manual hosts to seed discovery if CLI isn't available
  if [[ -n "${HA_HOST:-}" ]]; then
    try_list+=("${HA_HOST}")
    debug "Appended HA_HOST=${HA_HOST}"
  fi
  if [[ -n "${HA_IP:-}" ]]; then
    try_list+=("${HA_IP}")
    debug "Appended HA_IP=${HA_IP}"
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
    code="$(curl -m 2 -sS -o /dev/null -w '%{http_code}' "${url}/api/" 2>/dev/null)" || true
    debug "Tried ${url}/api/ -> ${code}"
    if is_http_reachable "$code"; then
      echo "$url"
      debug "Selected reachable URL ${url}"
      return 0
    fi
  done

  # Fallbacks if discovery fails (mDNS, docker parent, loopback inside host)
  for candidate in \
      "http://host.docker.internal:${HA_PORT}" \
      "http://supervisor:${HA_PORT}" \
      "http://172.30.32.1:${HA_PORT}" \
      "http://172.30.33.1:${HA_PORT}" \
      "http://172.17.0.1:${HA_PORT}"
  do
    local code
    code="$(curl -m 2 -sS -o /dev/null -w '%{http_code}' "${candidate}/api/" 2>/dev/null)" || true
    debug "Fallback try ${candidate}/api/ -> ${code}"
    if is_http_reachable "$code"; then
      echo "${candidate}"
      debug "Selected fallback URL ${candidate}"
      return 0
    fi
  done

  # Final fallbacks covering multicast DNS and localhost
  for candidate in \
      "http://homeassistant.local:${HA_PORT}" \
      "http://127.0.0.1:${HA_PORT}"
  do
    local code
    code="$(curl -m 2 -sS -o /dev/null -w '%{http_code}' "${candidate}/api/" 2>/dev/null)" || true
    debug "Final fallback try ${candidate}/api/ -> ${code}"
    if is_http_reachable "$code"; then
      echo "${candidate}"
      debug "Selected final fallback URL ${candidate}"
      return 0
    fi
  done

  debug "All discovery candidates exhausted"

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
  entity_list=""
  if command -v jq >/dev/null 2>&1; then
    entity_list="$(jq -r 'map(.entity_id) | join(", ")' <<<"$resp" 2>/dev/null || true)"
    [[ "$entity_list" == "null" ]] && entity_list=""
  fi

  if [[ -z "$entity_list" ]]; then
    entity_array=()
    mapfile -t entity_array < <(printf '%s\n' "$resp" | sed -n 's/.*"entity_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
    if (( ${#entity_array[@]} > 0 )); then
      entity_list="$(printf '%s, ' "${entity_array[@]}")"
      entity_list="${entity_list%, }"
    fi
  fi

  if [[ -n "$entity_list" && "$entity_list" != *"${SCRIPT_ENTITY}"* ]]; then
    echo "API response did not include ${SCRIPT_ENTITY}. Entities: ${entity_list}" >&2
    exit 2
  fi

  if [[ -z "$entity_list" ]]; then
    echo "Triggered ${SCRIPT_ENTITY} at ${HA_URL} (entity list unavailable)"
  else
    echo "Triggered ${SCRIPT_ENTITY} at ${HA_URL} (entities: ${entity_list})"
  fi
else
  echo "API call may have failed. Response:" >&2
  echo "$resp" >&2
  exit 2
fi
