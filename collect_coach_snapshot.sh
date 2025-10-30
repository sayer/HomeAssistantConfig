#!/usr/bin/env bash
set -euo pipefail

# Mirrors the authentication and discovery logic used by run_update_dynamic.sh
# to call script.collect_coach_snapshot and emit the JSON payload.

REMOTE_FILE="/config/.remote"
HA_PORT="${HA_PORT:-8123}"
TARGET_SERVICE="script.collect_coach_snapshot"
PAYLOAD='{"return_response": true}'

if [[ -r "$REMOTE_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$REMOTE_FILE"
fi
: "${HA_TOKEN:?Missing HA_TOKEN in /config/.remote}"

debug() {
  if [[ "${COLLECT_DEBUG:-0}" == "1" ]]; then
    echo "[collect] $*" >&2
  fi
}

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
  HA_URL="${HA_URL}"
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

tmp_body="$(mktemp)"
trap 'rm -f "$tmp_body"' EXIT

http_code="$(curl -sS -o "$tmp_body" -w '%{http_code}' \
  -X POST \
  -H "Authorization: Bearer ${HA_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "${PAYLOAD}" \
  "${HA_URL}/api/services/script/collect_coach_snapshot" \
  || true)"

if ! is_http_reachable "$http_code"; then
  cat "$tmp_body" >&2
  echo "HTTP request failed with status ${http_code}" >&2
  exit 2
fi

cat "$tmp_body"
