#!/bin/bash

# List of Home Assistant hosts
HOSTS=(
  "192.168.100.192"
  "homeassistant-16.tail73c84.ts.net"
  "homeassistant-15.tail73c84.ts.net"
  "homeassistant-14.tail73c84.ts.net"
  "homeassistant-12.tail73c84.ts.net"
  "homeassistant-13.tail73c84.ts.net"
  "homeassistant-3.tail73c84.ts.net"
  "homeassistant-8.tail73c84.ts.net"
)

ALL_HOSTS=("${HOSTS[@]}")
SSH_USER="hassio"
SSH_PORT=2222
SSH_OPTS=(-p "$SSH_PORT" -o ConnectTimeout=10 -o StrictHostKeyChecking=no)

SHORT_NAMES=("ping" "restart" "updates" "info" "update_ha_config" "reboot" "ssh" "docker" "pull")
COMMANDS=("" "ha core restart" "ha supervisor updates" "ha info" "/config/update_ha_config.sh" "ha host reboot" "" "" "cd /config && git pull origin main")

SUMMARY_RESULTS=()
CMD_TOTALS=()
CMD_SUCCESSES=()
CMD_FAILURES=()
OVERALL_EXIT=0

for _ in "${SHORT_NAMES[@]}"; do
  CMD_TOTALS+=(0)
  CMD_SUCCESSES+=(0)
  CMD_FAILURES+=(0)
done

usage() {
  echo "Usage: $0 [--host <pattern>] [ping] [restart] [updates] [info] [update_ha_config] [reboot] [ssh] [docker] [pull]"
  echo "  --host <pattern>   Only run commands on hosts matching the pattern (full or partial match)."
  echo "  ssh                Open an interactive SSH session to the specified host (must match exactly one host)."
  echo "  docker             Open an interactive SSH session to the specified host for Docker operations (must match exactly one host)."
  echo "  pull               Run git pull origin main in /config on the selected hosts."
  echo "You may specify one or more commands to run on all hosts or filtered hosts."
  exit 1
}
if [ $# -eq 0 ]; then
  usage
fi

find_cmd_index() {
  local target="$1"
  local i
  for i in "${!SHORT_NAMES[@]}"; do
    if [ "${SHORT_NAMES[$i]}" = "$target" ]; then
      echo "$i"
      return 0
    fi
  done
  echo "-1"
  return 1
}

record_result() {
  local short="$1"
  local host="$2"
  local status="$3"
  local note="$4"
  local message

  if [ -z "$note" ]; then
    if [ "$status" -eq 0 ]; then
      message="success"
    else
      message="failed (exit $status)"
    fi
  else
    message="$note"
  fi

  if [ "$status" -ne 0 ]; then
    OVERALL_EXIT=1
  fi

  SUMMARY_RESULTS+=("$short|$host|$status|$message")
  local idx
  idx=$(find_cmd_index "$short")
  if [ "$idx" -ge 0 ]; then
    CMD_TOTALS[$idx]=$(( ${CMD_TOTALS[$idx]} + 1 ))
    if [ "$status" -eq 0 ]; then
      CMD_SUCCESSES[$idx]=$(( ${CMD_SUCCESSES[$idx]} + 1 ))
    else
      CMD_FAILURES[$idx]=$(( ${CMD_FAILURES[$idx]} + 1 ))
    fi
  fi
}

print_summary() {
  if [ ${#SUMMARY_RESULTS[@]} -eq 0 ]; then
    return
  fi
  echo "====== Command Summary ======"
  SEEN_CMDS=()
  already_seen() {
    local check="$1"
    for item in "${SEEN_CMDS[@]}"; do
      if [ "$item" = "$check" ]; then
        return 0
      fi
    done
    return 1
  }
  mark_seen() {
    SEEN_CMDS+=("$1")
  }
  for cmd in "${SHORTS_TO_RUN[@]}"; do
    if already_seen "$cmd"; then
      continue
    fi
    mark_seen "$cmd"
    local idx
    idx=$(find_cmd_index "$cmd")
    local total=0
    local success=0
    local fail=0
    if [ "$idx" -ge 0 ]; then
      total=${CMD_TOTALS[$idx]}
      success=${CMD_SUCCESSES[$idx]}
      fail=${CMD_FAILURES[$idx]}
    fi
    echo "Command '$cmd': $success/$total succeeded"
    for entry in "${SUMMARY_RESULTS[@]}"; do
      IFS='|' read -r e_short e_host e_status e_message <<<"$entry"
      if [ "$e_short" = "$cmd" ]; then
        printf '  %s: %s\n' "$e_host" "$e_message"
      fi
    done
    if [ "$fail" -gt 0 ]; then
      echo "  Failures: $fail"
    fi
    echo ""
  done
}

# Host filter logic
HOST_FILTER=""
ARGS=("$@")
if [ "$1" = "--host" ]; then
  if [ $# -lt 3 ]; then
    echo "Error: --host requires a pattern and at least one command."
    usage
  fi
  HOST_FILTER="$2"
  # Remove --host and pattern from arguments
  ARGS=("${@:3}")
  # Allow explicit selection of all hosts
  HOST_FILTER_LOWER=$(printf '%s' "$HOST_FILTER" | tr '[:upper:]' '[:lower:]')
  if [ "$HOST_FILTER_LOWER" = "all" ]; then
    HOSTS=("${ALL_HOSTS[@]}")
  else
    # Filter HOSTS array
    FILTERED_HOSTS=()
    for h in "${ALL_HOSTS[@]}"; do
      if [[ "$h" == *"$HOST_FILTER"* ]]; then
        FILTERED_HOSTS+=("$h")
      fi
    done
    if [ ${#FILTERED_HOSTS[@]} -eq 0 ]; then
      echo "No hosts match pattern: $HOST_FILTER"
      exit 1
    fi
    HOSTS=("${FILTERED_HOSTS[@]}")
  fi
fi

# Build list of commands to run based on user input
COMMANDS_TO_RUN=()
SHORTS_TO_RUN=()
PULL_REQUESTED=0
PULL_SUCCESSES=()
PULL_FAILURES=()
PULL_FAILURE_LOGS=()
for arg in "${ARGS[@]}"; do
  found=0
  for i in "${!SHORT_NAMES[@]}"; do
    if [ "$arg" = "${SHORT_NAMES[$i]}" ]; then
      COMMANDS_TO_RUN+=("${COMMANDS[$i]}")
      SHORTS_TO_RUN+=("${SHORT_NAMES[$i]}")
      if [ "$arg" = "pull" ]; then
        PULL_REQUESTED=1
      fi
      found=1
      break
    fi
  done
  if [ $found -eq 0 ]; then
    echo "Unknown command: $arg"
    usage
  fi
done


for HOST in "${HOSTS[@]}"; do
  SSH_TARGET="${SSH_USER}@${HOST}"
  echo "=============================="
  echo "Connecting to $HOST"
  echo "=============================="
  for idx in "${!COMMANDS_TO_RUN[@]}"; do
    CMD="${COMMANDS_TO_RUN[$idx]}"
    SHORT="${SHORTS_TO_RUN[$idx]}"
    if [ "$SHORT" = "ssh" ]; then
      if [ ${#HOSTS[@]} -ne 1 ]; then
        echo "Error: The 'ssh' command requires exactly one host to be selected (use --host to specify)."
        exit 1
      fi
      echo "Opening interactive SSH session to $HOST..."
      ssh "${SSH_OPTS[@]}" "$SSH_TARGET"
      status=$?
      if [ $status -ne 0 ]; then
        echo "Error: SSH connection to $HOST failed (exit code $status)."
      fi
      record_result "$SHORT" "$HOST" "$status" ""
      print_summary
      exit $status
    elif [ "$SHORT" = "docker" ]; then
      if [ ${#HOSTS[@]} -ne 1 ]; then
        echo "Error: The 'docker' command requires exactly one host to be selected (use --host to specify)."
        exit 1
      fi
      echo "Running docker_shell.sh on $HOST..."
      ssh -t "${SSH_OPTS[@]}" "$SSH_TARGET" "bash /config/docker_shell.sh"
      status=$?
      if [ $status -ne 0 ]; then
        echo "Error: Docker shell on $HOST failed (exit code $status)."
      fi
      record_result "$SHORT" "$HOST" "$status" ""
      print_summary
      exit $status
    elif [ "$SHORT" = "ping" ]; then
      echo "Running: ping (SSH connectivity test)"
      ssh -t "${SSH_OPTS[@]}" "$SSH_TARGET" "echo pong"
      status=$?
      if [ $status -eq 0 ]; then
        echo "Ping successful: SSH connection to $HOST is working."
      else
        echo "Ping failed: Unable to connect to $HOST via SSH (exit code $status). Continuing to next host."
      fi
      record_result "$SHORT" "$HOST" "$status" ""
    elif [ "$CMD" = "/config/update_ha_config.sh" ]; then
      echo "Running: update_ha_config (with sudo)"
      ssh -t "${SSH_OPTS[@]}" "$SSH_TARGET" "sudo bash -l -c '$CMD'"
      status=$?
      if [ $status -ne 0 ]; then
        echo "Error: Failed to run '$CMD' with sudo on $HOST (exit code $status). Continuing to next host."
      fi
      record_result "$SHORT" "$HOST" "$status" ""
    elif [ "$SHORT" = "pull" ]; then
      echo "Running: git pull origin main"
      OUTPUT=$(ssh "${SSH_OPTS[@]}" "$SSH_TARGET" "$CMD" 2>&1)
      status=$?
      printf '%s\n' "$OUTPUT"
      if [ $status -eq 0 ]; then
        echo "Pull succeeded on $HOST."
        PULL_SUCCESSES+=("$HOST")
        note="updated"
        if echo "$OUTPUT" | grep -qi "already up to date"; then
          note="no changes"
        fi
        record_result "$SHORT" "$HOST" "$status" "$note"
      else
        echo "Error: git pull failed on $HOST (exit code $status). Continuing to next host."
        PULL_FAILURES+=("$HOST")
        PULL_FAILURE_LOGS+=("$OUTPUT")
        record_result "$SHORT" "$HOST" "$status" ""
      fi
    else
      echo "Running: $CMD"
      ssh -t "${SSH_OPTS[@]}" "$SSH_TARGET" "bash -l -c '$CMD'"
      status=$?
      if [ $status -ne 0 ]; then
        echo "Error: Failed to run '$CMD' on $HOST (exit code $status). Continuing to next host."
      fi
      record_result "$SHORT" "$HOST" "$status" ""
    fi
    echo "------------------------------"
  done
  echo ""
done

if [ $PULL_REQUESTED -eq 1 ]; then
  echo "====== Pull Summary ======"
  if [ ${#PULL_SUCCESSES[@]} -gt 0 ]; then
    echo "Pull succeeded on: ${PULL_SUCCESSES[*]}"
  else
    echo "Pull succeeded on: none"
  fi
  if [ ${#PULL_FAILURES[@]} -gt 0 ]; then
    echo "Pull failed on: ${PULL_FAILURES[*]}"
    echo "--- Failure Details ---"
    for i in "${!PULL_FAILURES[@]}"; do
      HOSTNAME="${PULL_FAILURES[$i]}"
      LOG="${PULL_FAILURE_LOGS[$i]}"
      echo "[$HOSTNAME]"
      printf '%s\n' "$LOG"
      echo "-----------------------"
    done
  else
    echo "Pull failed on: none"
  fi
fi

print_summary
exit $OVERALL_EXIT
