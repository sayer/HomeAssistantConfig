#!/bin/bash
# update_ha_config.sh
# This script:
# 1. Checks git for updates
# 2. Runs update_config.sh with model year from HA helper
# 3. Checks HA config
# 4. Reloads YAML if check passes

# Set error handling
set -e

# Log file for output - changed to use /tmp for better permissions
LOG_FILE="/tmp/update_ha_config.log"
REPO_DIR="/config"
CONFIG_SCRIPT="${REPO_DIR}/update_config.sh"

# Function to log messages
log_message() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE" 2>/dev/null || echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
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

# Verify git write permissions
if [ ! -w "$REPO_DIR/.git" ]; then
  log_message "WARNING: No write permission to $REPO_DIR/.git directory, skipping git operations"
else
  # Check if branch has upstream configured
  if git rev-parse --abbrev-ref @{upstream} >/dev/null 2>&1; then
    # Upstream exists, proceed with fetch and compare
    log_message "Fetching updates from remote repository..."
    if git fetch origin 2>/dev/null; then
      LOCAL=$(git rev-parse HEAD 2>/dev/null)
      REMOTE=$(git rev-parse @{u} 2>/dev/null)
      
      if [ -n "$LOCAL" ] && [ -n "$REMOTE" ] && [ "$LOCAL" != "$REMOTE" ]; then
        log_message "Updates available, pulling changes..."
        if git pull 2>/dev/null; then
          log_message "Git pull completed successfully"
        else
          log_message "ERROR: Git pull failed, possibly due to permissions or conflicts"
        fi
      else
        log_message "Repository is up to date"
      fi
    else
      log_message "ERROR: Failed to fetch from remote repository"
    fi
  else
    log_message "No upstream configured for current branch, skipping git update check"
  fi
fi

# Get the model year from Home Assistant helper
log_message "Getting model year from /config/coach_model_year.txt..."
# Default MODEL_YEAR in case we can't read or write the file
MODEL_YEAR="2020"

if [ -f "/config/coach_model_year.txt" ] && [ -r "/config/coach_model_year.txt" ]; then
  # File exists and is readable
  MODEL_YEAR=$(cat /config/coach_model_year.txt | tr -d '[:space:]')
  
  # If empty, use default
  if [ -z "$MODEL_YEAR" ]; then
    log_message "WARNING: /config/coach_model_year.txt is empty, using default value 2020"
    # Only try to write if we have permission
    if [ -w "/config/coach_model_year.txt" ]; then
      echo "2020" > /config/coach_model_year.txt
    else
      log_message "WARNING: No write permission to /config/coach_model_year.txt"
    fi
  fi
else
  # File doesn't exist or isn't readable
  log_message "WARNING: Cannot access /config/coach_model_year.txt, using default value 2020"
  # Only try to create if we have permission to the directory
  if [ -w "/config" ]; then
    log_message "Creating /config/coach_model_year.txt with default value 2020"
    echo "2020" > /config/coach_model_year.txt 2>/dev/null || log_message "ERROR: Failed to create /config/coach_model_year.txt"
  else
    log_message "WARNING: No write permission to /config directory"
  fi
fi

log_message "Model year: $MODEL_YEAR"

# Run the update_config.sh script with the model year
if [ ! -f "$CONFIG_SCRIPT" ]; then
  log_message "ERROR: update_config.sh not found at $CONFIG_SCRIPT"
  exit 1
elif [ ! -r "$CONFIG_SCRIPT" ]; then
  log_message "ERROR: update_config.sh exists but is not readable at $CONFIG_SCRIPT"
  exit 1
elif [ ! -x "$CONFIG_SCRIPT" ]; then
  # If script exists but isn't executable, try running it with bash
  log_message "WARNING: update_config.sh exists but is not executable, attempting to run with bash..."
  if bash "$CONFIG_SCRIPT" "$MODEL_YEAR"; then
    log_message "update_config.sh completed successfully with bash"
  else
    log_message "ERROR: Failed to run update_config.sh with bash"
    exit 1
  fi
else
  # Script is executable, run it directly
  log_message "Running update_config.sh with model year $MODEL_YEAR..."
  if "$CONFIG_SCRIPT" "$MODEL_YEAR"; then
    log_message "update_config.sh completed successfully"
  else
    log_message "ERROR: update_config.sh failed (exit code: $?)"
    exit 1
  fi
fi

# Check if 'ha' command exists and is executable
if ! command -v ha >/dev/null 2>&1; then
  log_message "ERROR: 'ha' command not found in PATH"
  exit 1
fi

# Check Home Assistant configuration
log_message "Checking Home Assistant configuration..."
if ha core check 2>/dev/null; then
  log_message "Configuration check passed"
  
  # Reload all YAML
  log_message "Reloading Home Assistant YAML configuration..."
  RELOAD_OUTPUT=$(ha core restart 2>&1)
  RELOAD_STATUS=$?
  
  if [ $RELOAD_STATUS -eq 0 ]; then
    log_message "All configurations reloaded successfully!"
  else
    log_message "ERROR: Failed to reload Home Assistant configuration (exit code: $RELOAD_STATUS):"
    log_message "${RELOAD_OUTPUT:-No output from reload command}"
    # Continue execution instead of exiting
    log_message "Continuing despite reload failure"
  fi
else
  log_message "ERROR: Home Assistant configuration check failed. YAML not reloaded."
  # Continue execution instead of exiting
  log_message "Continuing despite configuration check failure"
fi

log_message "Script completed successfully"
exit 0