#!/bin/bash
# update_ha_config.sh
# This script:
# 1. Checks git for updates
# 2. Runs update_config.sh with model year from HA helper
# 3. Checks HA config
# 4. Reloads YAML if check passes

# Set error handling
set -e

# Log file for output
LOG_FILE="/config/update_ha_config.log"
REPO_DIR="/config"
CONFIG_SCRIPT="${REPO_DIR}/update_config.sh"

# Function to log messages
log_message() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Start logging
log_message "Starting HA configuration update process"

# Check if we're in the correct directory
if [ ! -d "$REPO_DIR/.git" ]; then
  log_message "ERROR: Git repository not found at $REPO_DIR"
  exit 1
fi

# Change to the repository directory
cd "$REPO_DIR"
log_message "Changed to repository directory: $REPO_DIR"

# Check git for updates
log_message "Checking for git updates..."

# Check if branch has upstream configured
if git rev-parse --abbrev-ref @{upstream} >/dev/null 2>&1; then
  # Upstream exists, proceed with fetch and compare
  git fetch origin
  
  LOCAL=$(git rev-parse HEAD)
  REMOTE=$(git rev-parse @{u})
  
  if [ "$LOCAL" != "$REMOTE" ]; then
    log_message "Updates available, pulling changes..."
    git pull
    log_message "Git pull completed"
  else
    log_message "Repository is up to date"
  fi
else
  log_message "No upstream configured for current branch, skipping git update check"
fi

# Get the model year from Home Assistant helper
log_message "Getting model year from Home Assistant helper..."
MODEL_YEAR=$(ha state get input_number.model_year | grep state | cut -d'"' -f4 | cut -d'.' -f1)

if [ -z "$MODEL_YEAR" ]; then
  log_message "WARNING: Could not get model year from Home Assistant, defaulting to 2020"
  MODEL_YEAR="2020"
fi

log_message "Model year: $MODEL_YEAR"

# Run the update_config.sh script with the model year
if [ -x "$CONFIG_SCRIPT" ]; then
  log_message "Running update_config.sh with model year $MODEL_YEAR..."
  "$CONFIG_SCRIPT" "$MODEL_YEAR"
  log_message "update_config.sh completed"
else
  log_message "ERROR: update_config.sh not found or not executable at $CONFIG_SCRIPT"
  exit 1
fi

# Check Home Assistant configuration
log_message "Checking Home Assistant configuration..."
if ha core check; then
  log_message "Configuration check passed"
  
  # Reload all YAML
  log_message "Reloading Home Assistant YAML configuration..."
  RELOAD_OUTPUT=$(ha core reload 2>&1)
  RELOAD_STATUS=$?
  
  if [ $RELOAD_STATUS -eq 0 ]; then
    log_message "All configurations reloaded successfully!"
  else
    log_message "ERROR: Failed to reload Home Assistant configuration:"
    log_message "$RELOAD_OUTPUT"
    exit 1
  fi
else
  log_message "ERROR: Home Assistant configuration check failed. YAML not reloaded."
  exit 1
fi

log_message "Script completed successfully"
exit 0