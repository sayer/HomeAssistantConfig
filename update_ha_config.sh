#!/bin/bash
# update_ha_config.sh
# This script:
# 1. Checks git for updates
# 2. Runs update_config.sh with model year from HA helper
# 3. Checks HA config
# 4. Reloads YAML if check passes

set -o pipefail

# Log file for output - changed to use /tmp for better permissions
LOG_FILE="/tmp/update_ha_config.log"
REPO_DIR="/config"
CONFIG_SCRIPT="${REPO_DIR}/update_config.sh"

EXIT_CODE=0
GIT_RESULT="not-run"
CONFIG_RESULT="not-run"
HA_CHECK_RESULT="not-run"
RESTART_RESULT="not-run"
INITIAL_HEAD=""
INITIAL_STATUS=""
FINAL_HEAD=""
FINAL_STATUS=""
GIT_CHANGE_NOTE=""
GIT_STATUS_AVAILABLE=0

# Function to log messages
log_message() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE" 2>/dev/null || echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

capture_git_state() {
  if [ ! -d "$REPO_DIR/.git" ]; then
    GIT_CHANGE_NOTE="Git repository unavailable"
    FINAL_HEAD="unknown"
    FINAL_STATUS=""
    GIT_STATUS_AVAILABLE=0
    return
  fi

  FINAL_HEAD=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
  local status_output
  status_output=$(git status --porcelain=v1 2>/dev/null || echo "__GIT_STATUS_ERROR__")

  if [ "$status_output" = "__GIT_STATUS_ERROR__" ]; then
    GIT_CHANGE_NOTE="WARNING: Unable to read final git status"
    FINAL_STATUS=""
    GIT_STATUS_AVAILABLE=0
    return
  fi

  FINAL_STATUS="$status_output"
  GIT_STATUS_AVAILABLE=1

  local head_changed="no"
  local worktree_changed="no"

  if [ -n "$INITIAL_HEAD" ] && [ "$INITIAL_HEAD" != "unknown" ] && [ "$FINAL_HEAD" != "unknown" ] && [ "$INITIAL_HEAD" != "$FINAL_HEAD" ]; then
    head_changed="yes"
  fi

  if [ "$FINAL_STATUS" != "$INITIAL_STATUS" ]; then
    worktree_changed="yes"
  fi

  if [ "$head_changed" = "yes" ] || [ "$worktree_changed" = "yes" ]; then
    GIT_CHANGE_NOTE="changed (HEAD: $head_changed, worktree: $worktree_changed)"
  else
    GIT_CHANGE_NOTE="unchanged"
  fi
}

print_summary() {
  capture_git_state

  log_message "----- Update Summary -----"
  log_message "Git pull: $GIT_RESULT"
  log_message "Config render: $CONFIG_RESULT"
  log_message "HA core check: $HA_CHECK_RESULT"
  log_message "HA restart: $RESTART_RESULT"

  if [ -n "$GIT_CHANGE_NOTE" ]; then
    log_message "Git repo state: $GIT_CHANGE_NOTE"
  fi

  if [ $GIT_STATUS_AVAILABLE -eq 1 ]; then
    if [ -n "$FINAL_STATUS" ]; then
      log_message "Working tree changes:"
      while IFS= read -r status_line; do
        [ -n "$status_line" ] && log_message "  $status_line"
      done <<<"$FINAL_STATUS"
    else
      log_message "Working tree: clean"
    fi
  fi

  if [ $EXIT_CODE -eq 0 ]; then
    log_message "Overall result: SUCCESS"
  else
    log_message "Overall result: FAILURE (exit code $EXIT_CODE)"
  fi
}

main() {
  log_message "Starting HA configuration update process"

  if [ ! -d "$REPO_DIR/.git" ]; then
    log_message "ERROR: Git repository not found at $REPO_DIR"
    GIT_RESULT="failed (missing repo)"
    EXIT_CODE=1
    return 1
  fi

  if ! cd "$REPO_DIR"; then
    log_message "ERROR: Unable to change to repository directory $REPO_DIR"
    GIT_RESULT="failed (cannot access repo)"
    EXIT_CODE=1
    return 1
  fi

  log_message "Changed to repository directory: $REPO_DIR"

  # Capture initial git state so we can tell if anything changed
  INITIAL_HEAD=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
  INITIAL_STATUS=$(git status --porcelain=v1 2>/dev/null || echo "__GIT_STATUS_ERROR__")

  if [ "$INITIAL_STATUS" = "__GIT_STATUS_ERROR__" ]; then
    log_message "WARNING: Unable to read initial git status"
    INITIAL_STATUS=""
  elif [ -n "$INITIAL_STATUS" ]; then
    log_message "NOTICE: Repository has local changes before update"
  fi

  # Check git for updates
  log_message "Checking for git updates..."

  if [ ! -w "$REPO_DIR/.git" ]; then
    log_message "WARNING: No write permission to $REPO_DIR/.git directory, skipping git operations"
    GIT_RESULT="skipped (read-only)"
  else
    log_message "Running git pull origin main..."
    PULL_OUTPUT=$(git pull origin main 2>&1)
    PULL_STATUS=$?

    if [ -n "$PULL_OUTPUT" ]; then
      while IFS= read -r line; do
        log_message "git: $line"
      done <<<"$PULL_OUTPUT"
    fi

    if [ $PULL_STATUS -eq 0 ]; then
      if echo "$PULL_OUTPUT" | grep -qi "already up to date"; then
        GIT_RESULT="no updates"
      else
        GIT_RESULT="updated"
      fi
      log_message "Git pull origin main completed"
    else
      log_message "ERROR: git pull origin main failed (exit code: $PULL_STATUS)"
      GIT_RESULT="failed ($PULL_STATUS)"
      EXIT_CODE=1
    fi
  fi

  # Get the model year from Home Assistant helper
  log_message "Getting model year from /config/coach_model_year.txt..."
  MODEL_YEAR="2020"

  if [ -f "/config/coach_model_year.txt" ] && [ -r "/config/coach_model_year.txt" ]; then
    MODEL_YEAR=$(tr -d '[:space:]' < /config/coach_model_year.txt)

    if [ -z "$MODEL_YEAR" ]; then
      log_message "WARNING: /config/coach_model_year.txt is empty, using default value 2020"
      if [ -w "/config/coach_model_year.txt" ]; then
        echo "2020" > /config/coach_model_year.txt
      else
        log_message "WARNING: No write permission to /config/coach_model_year.txt"
      fi
      MODEL_YEAR="2020"
    fi
  else
    log_message "WARNING: Cannot access /config/coach_model_year.txt, using default value 2020"
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
    CONFIG_RESULT="failed (missing script)"
    EXIT_CODE=1
    return 1
  elif [ ! -r "$CONFIG_SCRIPT" ]; then
    log_message "ERROR: update_config.sh exists but is not readable at $CONFIG_SCRIPT"
    CONFIG_RESULT="failed (not readable)"
    EXIT_CODE=1
    return 1
  elif [ ! -x "$CONFIG_SCRIPT" ]; then
    log_message "WARNING: update_config.sh exists but is not executable, attempting to run with bash..."
    if bash "$CONFIG_SCRIPT" "$MODEL_YEAR"; then
      log_message "update_config.sh completed successfully with bash"
      CONFIG_RESULT="success (bash)"
    else
      log_message "ERROR: Failed to run update_config.sh with bash"
      CONFIG_RESULT="failed (bash execution)"
      EXIT_CODE=1
      return 1
    fi
  else
    log_message "Running update_config.sh with model year $MODEL_YEAR..."
    if "$CONFIG_SCRIPT" "$MODEL_YEAR"; then
      log_message "update_config.sh completed successfully"
      CONFIG_RESULT="success"
    else
      local config_exit=$?
      log_message "ERROR: update_config.sh failed (exit code: $config_exit)"
      CONFIG_RESULT="failed ($config_exit)"
      EXIT_CODE=1
      return 1
    fi
  fi

  # Check if 'ha' command exists and is executable
  if ! command -v ha >/dev/null 2>&1; then
    log_message "ERROR: 'ha' command not found in PATH"
    HA_CHECK_RESULT="'ha' command missing"
    EXIT_CODE=1
    return 1
  fi

  # Check Home Assistant configuration
  log_message "Checking Home Assistant configuration..."
  if ha core check 2>/dev/null; then
    log_message "Configuration check passed"
    HA_CHECK_RESULT="passed"

    log_message "Reloading Home Assistant YAML configuration..."
    RELOAD_OUTPUT=$(ha core restart 2>&1)
    RELOAD_STATUS=$?

    if [ $RELOAD_STATUS -eq 0 ]; then
      log_message "All configurations reloaded successfully!"
      RESTART_RESULT="success"
    else
      log_message "ERROR: Failed to reload Home Assistant configuration (exit code: $RELOAD_STATUS)"
      if [ -n "$RELOAD_OUTPUT" ]; then
        log_message "$RELOAD_OUTPUT"
      else
        log_message "No output from reload command"
      fi
      RESTART_RESULT="failed ($RELOAD_STATUS)"
      EXIT_CODE=1
    fi
  else
    log_message "ERROR: Home Assistant configuration check failed. YAML not reloaded."
    HA_CHECK_RESULT="failed"
    RESTART_RESULT="skipped"
    EXIT_CODE=1
  fi

  log_message "Update sequence finished"
  return $EXIT_CODE
}

main
EXIT_CODE=$?
print_summary
exit $EXIT_CODE
