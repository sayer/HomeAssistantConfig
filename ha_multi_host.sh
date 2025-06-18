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

SSH_USER="hassio"
SSH_PORT=2222

SHORT_NAMES=("ping" "restart" "updates" "info" "update_ha_config" "reboot" "ssh" "docker")
COMMANDS=("" "ha core restart" "ha supervisor updates" "ha info" "/config/update_ha_config.sh" "ha host reboot" "" "")

usage() {
  echo "Usage: $0 [--host <pattern>] [ping] [restart] [updates] [info] [update_ha_config] [reboot] [ssh] [docker]"
  echo "  --host <pattern>   Only run commands on hosts matching the pattern (full or partial match)."
  echo "  ssh                Open an interactive SSH session to the specified host (must match exactly one host)."
  echo "  docker             Open an interactive SSH session to the specified host for Docker operations (must match exactly one host)."
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
  # Filter HOSTS array
  FILTERED_HOSTS=()
  for h in "${HOSTS[@]}"; do
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

# Build list of commands to run based on user input
COMMANDS_TO_RUN=()
SHORTS_TO_RUN=()
for arg in "${ARGS[@]}"; do
  found=0
  for i in "${!SHORT_NAMES[@]}"; do
    if [ "$arg" = "${SHORT_NAMES[$i]}" ]; then
      COMMANDS_TO_RUN+=("${COMMANDS[$i]}")
      SHORTS_TO_RUN+=("${SHORT_NAMES[$i]}")
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
      ssh -p $SSH_PORT -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$SSH_USER@$HOST"
      exit $?
    elif [ "$SHORT" = "docker" ]; then
      if [ ${#HOSTS[@]} -ne 1 ]; then
        echo "Error: The 'docker' command requires exactly one host to be selected (use --host to specify)."
        exit 1
      fi
      echo "Running docker_shell.sh on $HOST..."
      ssh -t -p $SSH_PORT -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$SSH_USER@$HOST" "bash /config/docker_shell.sh"
      exit $?
    elif [ "$SHORT" = "ping" ]; then
      echo "Running: ping (SSH connectivity test)"
      ssh -t -p $SSH_PORT -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$SSH_USER@$HOST" "echo pong"
      if [ $? -eq 0 ]; then
        echo "Ping successful: SSH connection to $HOST is working."
      else
        echo "Ping failed: Unable to connect to $HOST via SSH."
      fi
    elif [ "$CMD" = "/config/update_ha_config.sh" ]; then
      echo "Running: update_ha_config (with sudo)"
      ssh -t -p $SSH_PORT -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$SSH_USER@$HOST" "sudo bash -l -c '$CMD'"
      if [ $? -ne 0 ]; then
        echo "Error: Failed to run '$CMD' with sudo on $HOST"
      fi
    else
      echo "Running: $CMD"
      ssh -t -p $SSH_PORT -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$SSH_USER@$HOST" "bash -l -c '$CMD'"
      if [ $? -ne 0 ]; then
        echo "Error: Failed to run '$CMD' on $HOST"
      fi
    fi
    echo "------------------------------"
  done
  echo ""
done