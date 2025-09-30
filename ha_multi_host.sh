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
    elif [ "$CMD" = "/config/update_ha_config.sh" ]; then
      echo "Running: update_ha_config (with sudo)"
      ssh -t "${SSH_OPTS[@]}" "$SSH_TARGET" "sudo bash -l -c '$CMD'"
      status=$?
      if [ $status -ne 0 ]; then
        echo "Error: Failed to run '$CMD' with sudo on $HOST (exit code $status). Continuing to next host."
      fi
    elif [ "$SHORT" = "pull" ]; then
      echo "Running: git pull origin main"
      OUTPUT=$(ssh "${SSH_OPTS[@]}" "$SSH_TARGET" "$CMD" 2>&1)
      status=$?
      printf '%s\n' "$OUTPUT"
      if [ $status -eq 0 ]; then
        echo "Pull succeeded on $HOST."
        PULL_SUCCESSES+=("$HOST")
      else
        echo "Error: git pull failed on $HOST (exit code $status). Continuing to next host."
        PULL_FAILURES+=("$HOST")
        PULL_FAILURE_LOGS+=("$OUTPUT")
      fi
    else
      echo "Running: $CMD"
      ssh -t "${SSH_OPTS[@]}" "$SSH_TARGET" "bash -l -c '$CMD'"
      status=$?
      if [ $status -ne 0 ]; then
        echo "Error: Failed to run '$CMD' on $HOST (exit code $status). Continuing to next host."
      fi
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
