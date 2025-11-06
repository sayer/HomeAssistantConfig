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
PYTHON_BIN="$(command -v python3 || command -v python || true)"

EXIT_CODE=0
GIT_RESULT="not-run"
CONFIG_RESULT="not-run"
DYNAMIC_SCRIPT_RESULT="skipped"
HA_CHECK_RESULT="not-run"
RESTART_RESULT="not-run"
ADDONS_RESULT="skipped"
HACS_RESULT="skipped"
CORE_UPDATE_NOTE="not checked"
INITIAL_HEAD=""
INITIAL_STATUS=""
FINAL_HEAD=""
FINAL_STATUS=""
GIT_CHANGE_NOTE=""
GIT_STATUS_AVAILABLE=0
HACS_STORAGE_FILE="/config/.storage/hacs.repositories"
RUN_DYNAMIC_SCRIPT="${REPO_DIR}/run_update_dynamic.sh"
REMOTE_CREDENTIAL_FILE="/config/.remote"

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
  log_message "Dynamic script trigger: $DYNAMIC_SCRIPT_RESULT"
  log_message "HA core check: $HA_CHECK_RESULT"
  log_message "HA restart: $RESTART_RESULT"
  log_message "HACS updates: $HACS_RESULT"
  log_message "Add-on updates: $ADDONS_RESULT"
  log_message "HA core update status: $CORE_UPDATE_NOTE"

  if [ -n "$GIT_CHANGE_NOTE" ]; then
    log_message "Git repo state: $GIT_CHANGE_NOTE"
  fi

  if [ $GIT_STATUS_AVAILABLE -eq 1 ]; then
    if [ -n "$FINAL_STATUS" ]; then
      local tracked_count
      local untracked_count
      tracked_count=$(printf '%s\n' "$FINAL_STATUS" | grep -vc '^??')
      untracked_count=$(printf '%s\n' "$FINAL_STATUS" | grep -c '^??')
      local summary_parts=()
      if [ "$tracked_count" -gt 0 ]; then
        summary_parts+=("${tracked_count} tracked")
      fi
      if [ "$untracked_count" -gt 0 ]; then
        summary_parts+=("${untracked_count} untracked")
      fi
      if [ ${#summary_parts[@]} -gt 0 ]; then
        local summary_joined
        local IFS=', '
        summary_joined="${summary_parts[*]}"
        log_message "Working tree dirty (${summary_joined})"
      else
        log_message "Working tree dirty"
      fi
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

check_core_update() {
  if ! command -v ha >/dev/null 2>&1; then
    CORE_UPDATE_NOTE="'ha' command missing"
    return 1
  fi

  local core_raw
  core_raw=$(ha core info --raw-json --no-progress 2>&1)
  local status=$?
  if [ $status -ne 0 ]; then
    CORE_UPDATE_NOTE="failed to query"
    log_message "WARNING: Unable to determine Home Assistant core version (ha core info exited $status)"
    if [ -n "$core_raw" ]; then
      while IFS= read -r line; do
        [ -n "$line" ] && log_message "ha core info: $line"
      done <<<"$core_raw"
    fi
    return 1
  fi

  local update_flag=""
  local version=""
  local latest=""
  local python_parse_failed=0
  if [ -n "$PYTHON_BIN" ]; then
    local parsed
    if ! parsed=$(printf '%s' "$core_raw" | "$PYTHON_BIN" - <<'PY'
import json, sys
try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(1)
core = data.get("data")
if core is None:
    core = data
update = core.get("update_available")
if update is None:
    update = core.get("version_update")
version = core.get("version")
latest = core.get("version_latest")
print(f"{1 if update else 0}|{version or ''}|{latest or ''}")
PY
); then
      python_parse_failed=1
    else
      IFS='|' read -r update_flag version latest <<<"$parsed"
    fi
  fi

  if [ -z "$PYTHON_BIN" ] || [ $python_parse_failed -eq 1 ]; then
    if [ $python_parse_failed -eq 1 ]; then
      log_message "WARNING: Python parsing of HA core info failed; using fallback parser"
    fi
    if echo "$core_raw" | grep -q '"update_available":[[:space:]]*true'; then
      update_flag=1
    else
      update_flag=0
    fi
    version=$(printf '%s' "$core_raw" | sed -n 's/.*"version":"\([^"]*\)".*/\1/p' | head -n1)
    latest=$(printf '%s' "$core_raw" | sed -n 's/.*"version_latest":"\([^"]*\)".*/\1/p' | head -n1)
  fi

  if [ "$update_flag" = "1" ]; then
    CORE_UPDATE_NOTE="update available (current: ${version:-unknown}, latest: ${latest:-unknown})"
    log_message "WARNING: Home Assistant core update available: current ${version:-unknown}, latest ${latest:-unknown}. Run 'ha core update' when ready."
  else
    CORE_UPDATE_NOTE="up-to-date (current: ${version:-unknown})"
  fi
}

update_addons() {
  log_message "Checking for Home Assistant add-on updates..."

  if ! command -v ha >/dev/null 2>&1; then
    log_message "WARNING: 'ha' command not available, skipping add-on update check"
    ADDONS_RESULT="'ha' command missing"
    return 1
  fi

  local addons_raw
  addons_raw=$(ha addons list --raw-json --no-progress 2>&1)
  local status=$?
  if [ $status -ne 0 ]; then
    log_message "WARNING: Unable to retrieve add-on list (ha addons list exited $status); skipping updates"
    if [ -n "$addons_raw" ]; then
      while IFS= read -r line; do
        [ -n "$line" ] && log_message "ha addons list: $line"
      done <<<"$addons_raw"
    fi
    ADDONS_RESULT="failed (list)"
    return 1
  fi

  local slugs=""
  local parse_failed=0
  local python_parse_failed=0
  if [ -n "$PYTHON_BIN" ]; then
    slugs=$(printf '%s' "$addons_raw" | "$PYTHON_BIN" - <<'PY'
import json, sys
try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(1)
addons = data.get("data", {}).get("addons", [])
for addon in addons:
    if addon.get("update_available"):
        slug = addon.get("slug")
        if slug:
            print(slug)
PY
)
    if [ $? -ne 0 ]; then
      python_parse_failed=1
    fi
  fi

  if [ -z "$PYTHON_BIN" ] || [ $python_parse_failed -eq 1 ]; then
    if [ $python_parse_failed -eq 1 ]; then
      log_message "WARNING: Python parsing of add-on list failed; using fallback parser"
    fi
    if echo "$addons_raw" | grep -q '"update_available":[[:space:]]*true'; then
      slugs=$(printf '%s' "$addons_raw" | sed -n 's/{\"name\":\"[^\"]*\",\"slug\":\"\([^\"]*\)\",[^}]*\"update_available\":true.*/\1/p')
    else
      slugs=""
    fi
    parse_failed=0
  fi

  if [ $python_parse_failed -eq 1 ] && [ -z "$slugs" ] && echo "$addons_raw" | grep -q '"update_available":[[:space:]]*true'; then
    parse_failed=1
  fi

  if [ $parse_failed -eq 1 ]; then
    log_message "WARNING: Failed to parse add-on list JSON"
    if [ -n "$addons_raw" ]; then
      while IFS= read -r line; do
        [ -n "$line" ] && log_message "ha addons list: $line"
      done <<<"$addons_raw"
    fi
    ADDONS_RESULT="failed (parse)"
    return 1
  fi

  if [ -z "$slugs" ]; then
    log_message "No add-ons require updates"
    ADDONS_RESULT="no updates"
    return 0
  fi

  local update_failed=0
  while IFS= read -r slug; do
    [ -z "$slug" ] && continue
    log_message "Updating add-on: $slug"
    local update_output
    if update_output=$(ha addons update "$slug" --no-progress 2>&1); then
      if [ -n "$update_output" ]; then
        while IFS= read -r line; do
          [ -n "$line" ] && log_message "addon[$slug]: $line"
        done <<<"$update_output"
      fi
      log_message "Add-on $slug updated successfully"
    else
      log_message "ERROR: Failed to update add-on $slug"
      if [ -n "$update_output" ]; then
        while IFS= read -r line; do
          [ -n "$line" ] && log_message "addon[$slug]: $line"
        done <<<"$update_output"
      fi
      update_failed=1
    fi
  done <<<"$slugs"

  if [ $update_failed -eq 0 ]; then
    ADDONS_RESULT="updated"
    return 0
  else
    ADDONS_RESULT="partial failure"
    EXIT_CODE=1
    return 1
  fi
}

update_hacs() {
  log_message "Checking for HACS integration updates..."

  if [ ! -f "$HACS_STORAGE_FILE" ]; then
    log_message "HACS storage file not found at $HACS_STORAGE_FILE; assuming HACS not installed"
    HACS_RESULT="not installed"
    return 0
  fi

  if [ -z "$PYTHON_BIN" ]; then
    log_message "WARNING: No python interpreter available; skipping HACS updates"
    HACS_RESULT="skipped (no python)"
    return 1
  fi

  local parse_output
  local status
  parse_output=$(HACS_REPO_FILE="$HACS_STORAGE_FILE" "$PYTHON_BIN" - <<'PY'
import json
import os
import sys

path = os.environ.get("HACS_REPO_FILE")
if not path:
    sys.exit(3)

try:
    with open(path, "r", encoding="utf-8") as fh:
        content = json.load(fh)
except FileNotFoundError:
    sys.exit(2)
except Exception:
    sys.exit(1)

repos = []
if isinstance(content, dict):
    data = content.get("data")
    if isinstance(data, dict):
        repos = data.get("repos") or data.get("repositories") or data.get("items") or []
        if isinstance(repos, dict):
            repos = list(repos.values())
    elif isinstance(data, list):
        repos = data
    else:
        repos = []
    if not repos and isinstance(content.get("repositories"), list):
        repos = content["repositories"]
elif isinstance(content, list):
    repos = content

updates = []
for repo in repos:
    if not isinstance(repo, dict):
        continue
    if not repo.get("installed", False):
        continue
    pending = repo.get("pending_update")
    if pending is None:
        installed = repo.get("installed_version")
        available = repo.get("available_version") or repo.get("version") or repo.get("last_version")
        if installed and available and installed != available:
            pending = True
        else:
            pending = False
    if not pending:
        continue
    repo_id = repo.get("repository_id") or repo.get("id") or repo.get("full_name")
    if not repo_id:
        continue
    name = repo.get("full_name") or repo.get("name") or str(repo_id)
    updates.append((str(repo_id), name))

for repo_id, name in updates:
    sys.stdout.write(f"{repo_id}|{name}\n")
PY
)
  status=$?

  if [ $status -eq 2 ]; then
    log_message "HACS storage file disappeared during processing; skipping updates"
    HACS_RESULT="not installed"
    return 0
  elif [ $status -ne 0 ]; then
    log_message "WARNING: Failed to parse HACS repository metadata (exit status $status)"
    HACS_RESULT="failed (parse)"
    EXIT_CODE=1
    return 1
  fi

  if [ -z "$parse_output" ]; then
    log_message "No HACS integrations require updates"
    HACS_RESULT="no updates"
    return 0
  fi

  local update_failed=0
  while IFS='|' read -r repo_id repo_name; do
    [ -z "$repo_id" ] && continue
    local repo_display="${repo_name:-$repo_id}"
    log_message "Updating HACS repository $repo_display (id $repo_id)"
    local args
    args=$(printf '{"repository":"%s"}' "$repo_id")
    local update_output
    if update_output=$(ha service call hacs.repository_update --no-progress --arguments "$args" 2>&1); then
      if [ -n "$update_output" ]; then
        while IFS= read -r line; do
          [ -n "$line" ] && log_message "hacs[$repo_display]: $line"
        done <<<"$update_output"
      fi
      log_message "HACS repository $repo_display updated successfully"
      continue
    fi

    log_message "WARNING: HACS update via repository id failed for $repo_display; retrying with repository name"
    if [ -n "$update_output" ]; then
      while IFS= read -r line; do
        [ -n "$line" ] && log_message "hacs[$repo_display]: $line"
      done <<<"$update_output"
    fi

    local args_name
    args_name=$(printf '{"repository":"%s"}' "$repo_display")
    if update_output=$(ha service call hacs.repository_update --no-progress --arguments "$args_name" 2>&1); then
      if [ -n "$update_output" ]; then
        while IFS= read -r line; do
          [ -n "$line" ] && log_message "hacs[$repo_display]: $line"
        done <<<"$update_output"
      fi
      log_message "HACS repository $repo_display updated successfully via name fallback"
    else
      log_message "ERROR: Failed to update HACS repository $repo_display"
      if [ -n "$update_output" ]; then
        while IFS= read -r line; do
          [ -n "$line" ] && log_message "hacs[$repo_display]: $line"
        done <<<"$update_output"
      fi
      update_failed=1
    fi
  done <<<"$parse_output"

  if [ $update_failed -eq 0 ]; then
    HACS_RESULT="updated"
    return 0
  else
    HACS_RESULT="partial failure"
    EXIT_CODE=1
    return 1
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
  local REPO_DIRTY=0
  local STASH_CREATED=0
  local STASH_REF=""
  local STASH_NAME=""

  if [ "$INITIAL_STATUS" = "__GIT_STATUS_ERROR__" ]; then
    log_message "WARNING: Unable to read initial git status"
    INITIAL_STATUS=""
  elif [ -n "$INITIAL_STATUS" ]; then
    local tracked_lines_raw
    local tracked_ignored_www_count=0
    local tracked_effective_count=0
    local untracked_changes

    tracked_lines_raw=$(printf '%s\n' "$INITIAL_STATUS" | grep -v '^??' || true)
    if [ -n "$tracked_lines_raw" ]; then
      local status_line path
      while IFS= read -r status_line; do
        [ -z "$status_line" ] && continue
        path="${status_line:3}"
        path="${path## }"
        # Normalize rename entries (old -> new)
        if [[ "$path" == *" -> "* ]]; then
          local old_path="${path%% -> *}"
          local new_path="${path##* -> }"
          old_path="${old_path## }"
          new_path="${new_path## }"
          if [[ "$old_path" == www/* && "$new_path" == www/* ]]; then
            tracked_ignored_www_count=$((tracked_ignored_www_count + 1))
            continue
          fi
          path="$new_path"
        fi
        if [[ "$path" == www/* ]]; then
          tracked_ignored_www_count=$((tracked_ignored_www_count + 1))
          continue
        fi
        tracked_effective_count=$((tracked_effective_count + 1))
      done <<<"$tracked_lines_raw"
    fi

    untracked_changes=$(printf '%s\n' "$INITIAL_STATUS" | grep -c '^??' || true)

    if [ "$tracked_effective_count" -gt 0 ]; then
      log_message "NOTICE: Repository has tracked changes before update"
      REPO_DIRTY=1
    else
      if [ "$tracked_ignored_www_count" -gt 0 ]; then
        log_message "NOTICE: Tracked changes under www/ ignored for git pull"
      fi
      if [ "${untracked_changes:-0}" -gt 0 ]; then
        log_message "NOTICE: Repository has untracked files (ignored for git pull)"
      fi
      REPO_DIRTY=0
    fi
  else
    REPO_DIRTY=0
  fi

  # Check git for updates
  log_message "Checking for git updates..."

  if [ ! -w "$REPO_DIR/.git" ]; then
    log_message "WARNING: No write permission to $REPO_DIR/.git directory, skipping git operations"
    GIT_RESULT="skipped (read-only)"
  else
    if [ $REPO_DIRTY -eq 1 ]; then
      STASH_NAME="ha-update-autostash-$(date +%s)"
      log_message "NOTICE: Local tracked changes detected; stashing as $STASH_NAME to allow git pull"
      STASH_OUTPUT=$(git stash push -m "$STASH_NAME" 2>&1)
      STASH_STATUS=$?

      if [ -n "$STASH_OUTPUT" ]; then
        while IFS= read -r line; do
          [ -n "$line" ] && log_message "stash: $line"
        done <<<"$STASH_OUTPUT"
      fi

      if [ $STASH_STATUS -eq 0 ]; then
        if echo "$STASH_OUTPUT" | grep -qi "No local changes to save"; then
          log_message "WARNING: git stash reported no changes; proceeding without stash"
        else
          STASH_REF=$(git stash list | head -n 1 | cut -d: -f1)
          if [ -z "$STASH_REF" ]; then
            STASH_REF="stash@{0}"
          fi
          STASH_CREATED=1
          log_message "Local changes stashed to $STASH_REF"
        fi
      else
        log_message "WARNING: Failed to stash local changes (exit code: $STASH_STATUS); proceeding without stash"
      fi
    fi

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

    if [ $STASH_CREATED -eq 1 ]; then
      if [ $PULL_STATUS -eq 0 ]; then
        log_message "Restoring stashed changes from $STASH_REF..."
        POP_OUTPUT=$(git stash pop "$STASH_REF" 2>&1)
        POP_STATUS=$?

        if [ -n "$POP_OUTPUT" ]; then
          while IFS= read -r line; do
            [ -n "$line" ] && log_message "stash: $line"
          done <<<"$POP_OUTPUT"
        fi

        if [ $POP_STATUS -eq 0 ]; then
          log_message "Stashed changes restored successfully"
        else
          log_message "ERROR: Failed to reapply stashed changes (exit code: $POP_STATUS)"
          GIT_RESULT="$GIT_RESULT; stash pop failed"
          EXIT_CODE=1
        fi
      else
        log_message "NOTICE: Local changes remain stashed at $STASH_REF due to git pull failure. Reapply manually with 'git stash pop $STASH_REF' after resolving issues."
      fi
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

  # Trigger dynamic update script via REST automation (best effort)
  local dynamic_cmd=()
  local dynamic_output=""
  local dynamic_status=0
  local has_dynamic_token=0

  if [ -n "${HA_TOKEN:-}" ]; then
    has_dynamic_token=1
  elif [ -r "$REMOTE_CREDENTIAL_FILE" ] && grep -Eqs '^[[:space:]]*HA_TOKEN=' "$REMOTE_CREDENTIAL_FILE"; then
    has_dynamic_token=1
  fi

  if [ $has_dynamic_token -eq 0 ]; then
    DYNAMIC_SCRIPT_RESULT="skipped (missing HA_TOKEN)"
    if [ -r "$REMOTE_CREDENTIAL_FILE" ]; then
      log_message "WARNING: Skipping run_update_dynamic.sh because HA_TOKEN is not set in the environment or $REMOTE_CREDENTIAL_FILE"
    else
      log_message "WARNING: Skipping run_update_dynamic.sh because HA_TOKEN is not set in the environment and $REMOTE_CREDENTIAL_FILE is missing"
    fi
  else
    if [ -x "$RUN_DYNAMIC_SCRIPT" ]; then
      dynamic_cmd=("$RUN_DYNAMIC_SCRIPT")
    elif [ -r "$RUN_DYNAMIC_SCRIPT" ]; then
      log_message "NOTICE: run_update_dynamic.sh not executable; invoking with bash"
      dynamic_cmd=(bash "$RUN_DYNAMIC_SCRIPT")
    fi

    if [ ${#dynamic_cmd[@]} -gt 0 ]; then
      log_message "Triggering script.update_all_outdated via run_update_dynamic.sh..."
      dynamic_output="$("${dynamic_cmd[@]}" 2>&1)"
      dynamic_status=$?
      if [ $dynamic_status -eq 0 ]; then
        DYNAMIC_SCRIPT_RESULT="success"
        if [ -n "$dynamic_output" ]; then
          while IFS= read -r line; do
            [ -n "$line" ] && log_message "dynamic: $line"
          done <<<"$dynamic_output"
        fi
      else
        if printf '%s\n' "$dynamic_output" | grep -q "Missing HA_TOKEN"; then
          DYNAMIC_SCRIPT_RESULT="skipped (missing HA_TOKEN)"
          log_message "WARNING: run_update_dynamic.sh reported missing HA_TOKEN; skipping"
        else
          DYNAMIC_SCRIPT_RESULT="failed ($dynamic_status)"
          log_message "ERROR: run_update_dynamic.sh failed (exit code: $dynamic_status)"
        fi
        if [ -n "$dynamic_output" ]; then
          while IFS= read -r line; do
            [ -n "$line" ] && log_message "dynamic: $line"
          done <<<"$dynamic_output"
        fi
      fi
    else
      DYNAMIC_SCRIPT_RESULT="skipped (missing script)"
      log_message "WARNING: run_update_dynamic.sh not found or not readable at $RUN_DYNAMIC_SCRIPT"
    fi
  fi

  # Check if 'ha' command exists and is executable
  if ! command -v ha >/dev/null 2>&1; then
    log_message "ERROR: 'ha' command not found in PATH"
    HA_CHECK_RESULT="'ha' command missing"
    EXIT_CODE=1
    return 1
  fi

  check_core_update

  # Check Home Assistant configuration
  log_message "Checking Home Assistant configuration..."
  HA_CHECK_OUTPUT=$(ha core check 2>&1)
  HA_CHECK_STATUS=$?
  if [ $HA_CHECK_STATUS -eq 0 ]; then
    if [ -n "$HA_CHECK_OUTPUT" ]; then
      while IFS= read -r line; do
        [ -n "$line" ] && log_message "ha core check: $line"
      done <<<"$HA_CHECK_OUTPUT"
    fi
    log_message "Configuration check passed"
    HA_CHECK_RESULT="passed"

    if update_hacs; then
      log_message "HACS update step completed"
    else
      log_message "WARNING: Issues encountered during HACS update step"
    fi

    log_message "Reloading Home Assistant YAML configuration..."
    RELOAD_OUTPUT=$(ha core restart 2>&1)
    RELOAD_STATUS=$?

    if [ $RELOAD_STATUS -eq 0 ]; then
      log_message "All configurations reloaded successfully!"
      RESTART_RESULT="success"
      update_addons
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
    if [ -n "$HA_CHECK_OUTPUT" ]; then
      while IFS= read -r line; do
        [ -n "$line" ] && log_message "ha core check: $line"
      done <<<"$HA_CHECK_OUTPUT"
    fi
    HA_CHECK_RESULT="failed"
    RESTART_RESULT="skipped"
    EXIT_CODE=1
    ADDONS_RESULT="skipped"
  fi

  log_message "Update sequence finished"
  return $EXIT_CODE
}

main
EXIT_CODE=$?
print_summary
exit $EXIT_CODE
