#!/bin/bash

# List of Home Assistant hosts
HOSTS=(
  "192.168.100.192"
  "homeassistant-12.tail73c84.ts.net"
  "homeassistant-13.tail73c84.ts.net"
  "homeassistant-3.tail73c84.ts.net"
)

SSH_USER="hassio"
SSH_PORT=2222

SHORT_NAMES=("ping" "restart" "updates" "info" "update_ha_config" "reboot")
COMMANDS=("" "ha core restart" "ha supervisor updates" "ha info" "/config/update_ha_config.sh" "ha host reboot")

usage() {
  echo "Usage: $0 [ping] [restart] [updates] [info] [update_ha_config] [reboot]"
  echo "You may specify one or more commands to run on all hosts."
  exit 1
}

if [ $# -eq 0 ]; then
  usage
fi

# Build list of commands to run based on user input
COMMANDS_TO_RUN=()
SHORTS_TO_RUN=()
for arg in "$@"; do
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
    if [ "$SHORT" = "ping" ]; then
      echo "Running: ping (SSH connectivity test)"
      ssh -t -p $SSH_PORT -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$SSH_USER@$HOST" "echo pong"
      if [ $? -eq 0 ]; then
        echo "Ping successful: SSH connection to $HOST is working."
      else
        echo "Ping failed: Unable to connect to $HOST via SSH."
      fi
    elif [ "$CMD" = "/config/update_ha_config.sh" ]; then
      echo "Running: update_ha_config"
      echo "Note: If you see 'Permission denied' for /config/update_ha_config.log, check permissions on the remote host."
      ssh -t -p $SSH_PORT -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$SSH_USER@$HOST" "bash -l -c '$CMD'"
      if [ $? -ne 0 ]; then
        echo "Error: Failed to run '$CMD' on $HOST"
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