#!/bin/bash

# List of Home Assistant hosts
HOSTS=(
  "homeassistant-20.tail73c84.ts.net"
  "homeassistant-19.tail73c84.ts.net"
  "homeassistant-18.tail73c84.ts.net"
  "homeassistant-17.tail73c84.ts.net"
  "homeassistant-16.tail73c84.ts.net"
  "homeassistant-13.tail73c84.ts.net"
  "homeassistant-12.tail73c84.ts.net"
  "homeassistant-8.tail73c84.ts.net"
  "homeassistant-4.tail73c84.ts.net"
  "homeassistant-3.tail73c84.ts.net"
)

ALL_HOSTS=("${HOSTS[@]}")
SSH_USER="hassio"
SSH_PORT=2222
SSH_OPTS=(-p "$SSH_PORT" -o ConnectTimeout=10 -o StrictHostKeyChecking=no)

if [ -t 1 ]; then
  COLOR_RESET=$'\033[0m'
  COLOR_BOLD=$'\033[1m'
  COLOR_GREEN=$'\033[32m'
  COLOR_RED=$'\033[31m'
  COLOR_YELLOW=$'\033[33m'
  COLOR_BLUE=$'\033[34m'
  COLOR_CYAN=$'\033[36m'
else
  COLOR_RESET=""
  COLOR_BOLD=""
  COLOR_GREEN=""
  COLOR_RED=""
  COLOR_YELLOW=""
  COLOR_BLUE=""
  COLOR_CYAN=""
fi

SHORT_NAMES=("ping" "restart" "updates" "info" "stats" "update_ha_config" "reboot" "ssh" "docker" "pull")
COMMANDS=(
  ""
  "ha core restart"
  "ha supervisor updates"
  "ha info"
  "/config/collect_coach_snapshot.sh"
  "/config/update_ha_config.sh"
  "ha host reboot"
  ""
  ""
  "cd /config && git pull origin main"
)

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
  echo "Usage: $0 [--host <pattern>] [ping] [restart] [updates] [info] [stats] [update_ha_config] [reboot] [ssh] [docker] [pull]"
  echo "  --host <pattern>   Limit commands to a single host (pattern must resolve to exactly one host)."
  echo "                     Omit --host or use '--host all' to run against every host (parallel for non-interactive commands)."
  echo "  ssh                Open an interactive SSH session to the specified host (must match exactly one host)."
  echo "  docker             Open an interactive SSH session to the specified host for Docker operations (must match exactly one host)."
  echo "  pull               Run git pull origin main in /config on the selected hosts."
  echo "  stats              Query Home Assistant template API for coach metrics JSON."
  echo "You may specify one or more commands to run on all hosts or a single selected host."
  exit 1
}
if [ $# -eq 0 ]; then
  usage
fi

progress_line() {
  local phase="$1"
  shift
  local message="$*"
  local label="INFO"
  local color="$COLOR_BLUE"

  case "$phase" in
    start)
      label="START"
      color="$COLOR_BLUE"
      ;;
    step)
      label="STEP"
      color="$COLOR_CYAN"
      ;;
    success)
      label="DONE"
      color="$COLOR_GREEN"
      ;;
    fail)
      label="FAIL"
      color="$COLOR_RED"
      ;;
    warn)
      label="WARN"
      color="$COLOR_YELLOW"
      ;;
    info|*)
      label="INFO"
      color="$COLOR_BLUE"
      ;;
  esac

  printf '%b[%s]%b %s\n' "${COLOR_BOLD}${color}" "$label" "$COLOR_RESET" "$message"
}

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

  local line="$short|$host|$status|$message"

  if [ -n "${RESULTS_FILE:-}" ]; then
    printf '%s\n' "$line" >>"$RESULTS_FILE"
    return
  fi

  process_result_line "$line"
}

process_result_line() {
  local line="$1"
  local short=""
  local host=""
  local status=""
  local message=""

  IFS='|' read -r short host status message <<<"$line"

  if [ -z "$short" ] || [ -z "$host" ] || [ -z "$status" ]; then
    return
  fi

  if [ "$status" -ne 0 ]; then
    OVERALL_EXIT=1
  fi

  SUMMARY_RESULTS+=("$line")
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

run_commands_for_host() {
  local host_index="$1"
  local host="$2"
  local output_file="$3"
  local result_file="$4"
  local pull_output_file="$5"
  local notify_fifo="$6"

  local ssh_target="${SSH_USER}@${host}"
  local host_exit=0
  local idx
  local CMD
  local SHORT
  local status
  local OUTPUT
  local note

  RESULTS_FILE="$result_file"
  PULL_OUTPUT_FILE="$pull_output_file"
  local total_cmds=${#COMMANDS_TO_RUN[@]}

  : >"$result_file"
  : >"$output_file"
  : >"$pull_output_file"

  {
    echo "=============================="
    echo "Connecting to $host"
    echo "=============================="
    for idx in "${!COMMANDS_TO_RUN[@]}"; do
      CMD="${COMMANDS_TO_RUN[$idx]}"
      SHORT="${SHORTS_TO_RUN[$idx]}"
      local human_idx=$(( idx + 1 ))
      progress_line step "$(printf '%s: command %d/%d -> %s' "$host" "$human_idx" "$total_cmds" "$SHORT")"
      case "$SHORT" in
        ping)
          echo "Running: ping (SSH connectivity test)"
          ssh -t "${SSH_OPTS[@]}" "$ssh_target" "echo pong"
          status=$?
          if [ $status -eq 0 ]; then
            echo "Ping successful: SSH connection to $host is working."
          else
            echo "Ping failed: Unable to connect to $host via SSH (exit code $status). Continuing to next host."
          fi
          record_result "$SHORT" "$host" "$status" ""
          ;;
        update_ha_config)
          echo "Running: update_ha_config (with sudo)"
          ssh -t "${SSH_OPTS[@]}" "$ssh_target" "sudo bash -l -c '$CMD'"
          status=$?
          if [ $status -ne 0 ]; then
            echo "Error: Failed to run '$CMD' with sudo on $host (exit code $status). Continuing to next host."
          fi
          record_result "$SHORT" "$host" "$status" ""
          ;;
        pull)
          echo "Running: git pull origin main (autostash)"
          OUTPUT=$(ssh "${SSH_OPTS[@]}" "$ssh_target" 'bash -s' <<'REMOTE'
#!/bin/bash
set -o pipefail

log_message() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

REPO_DIR="/config"
RESULT_NOTE="failed"
EXIT_STATUS=1

if [ ! -d "$REPO_DIR" ]; then
  log_message "ERROR: Repository directory $REPO_DIR not found"
  RESULT_NOTE="missing_repo"
  echo "PULL_RESULT: $RESULT_NOTE"
  exit $EXIT_STATUS
fi

if [ ! -d "$REPO_DIR/.git" ]; then
  log_message "ERROR: Git repository not found at $REPO_DIR"
  RESULT_NOTE="missing_git"
  echo "PULL_RESULT: $RESULT_NOTE"
  exit $EXIT_STATUS
fi

if ! cd "$REPO_DIR"; then
  log_message "ERROR: Unable to change to repository directory $REPO_DIR"
  RESULT_NOTE="cannot_access_repo"
  echo "PULL_RESULT: $RESULT_NOTE"
  exit $EXIT_STATUS
fi

log_message "Changed to repository directory: $REPO_DIR"

INITIAL_STATUS=$(git status --porcelain=v1 2>/dev/null || echo "__GIT_STATUS_ERROR__")
REPO_DIRTY=0
STASH_CREATED=0
STASH_REF=""

if [ "$INITIAL_STATUS" = "__GIT_STATUS_ERROR__" ]; then
  log_message "WARNING: Unable to read initial git status"
  INITIAL_STATUS=""
elif [ -n "$INITIAL_STATUS" ]; then
  tracked_lines_raw=$(printf '%s\n' "$INITIAL_STATUS" | grep -v '^??' || true)
  tracked_ignored_www_count=0
  tracked_effective_count=0

  if [ -n "$tracked_lines_raw" ]; then
    while IFS= read -r status_line; do
      [ -z "$status_line" ] && continue
      path="${status_line:3}"
      path="${path## }"
      if [[ "$path" == *" -> "* ]]; then
        old_path="${path%% -> *}"
        new_path="${path##* -> }"
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

  if [ "$tracked_effective_count" -gt 0 ]; then
    log_message "NOTICE: Repository has tracked changes before pull"
    REPO_DIRTY=1
  else
    if [ "$tracked_ignored_www_count" -gt 0 ]; then
      log_message "NOTICE: Tracked changes under www/ ignored for git pull"
    fi
    untracked_changes=$(printf '%s\n' "$INITIAL_STATUS" | grep -c '^??' || true)
    if [ "${untracked_changes:-0}" -gt 0 ]; then
      log_message "NOTICE: Repository has untracked files (ignored for git pull)"
    fi
    REPO_DIRTY=0
  fi
fi

log_message "Checking for git updates..."

if [ ! -w "$REPO_DIR/.git" ]; then
  log_message "WARNING: No write permission to $REPO_DIR/.git directory, skipping git operations"
  RESULT_NOTE="skipped_read_only"
  echo "PULL_RESULT: $RESULT_NOTE"
  exit 0
fi

if [ $REPO_DIRTY -eq 1 ]; then
  STASH_NAME="ha-multi-pull-autostash-$(date +%s)"
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
    [ -n "$line" ] && log_message "git: $line"
  done <<<"$PULL_OUTPUT"
fi

EXIT_STATUS=$PULL_STATUS

if [ $PULL_STATUS -eq 0 ]; then
  if echo "$PULL_OUTPUT" | grep -qi "already up to date"; then
    RESULT_NOTE="no_updates"
  else
    RESULT_NOTE="updated"
  fi
  log_message "Git pull origin main completed"
else
  RESULT_NOTE="pull_failed"
  log_message "ERROR: git pull origin main failed (exit code: $PULL_STATUS)"
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
      RESULT_NOTE="stash_pop_failed"
      EXIT_STATUS=$POP_STATUS
    fi
  else
    log_message "NOTICE: Local changes remain stashed at $STASH_REF due to git pull failure. Reapply manually with 'git stash pop $STASH_REF' after resolving issues."
  fi
fi

echo "PULL_RESULT: $RESULT_NOTE"
exit $EXIT_STATUS
REMOTE
)
          status=$?
          printf '%s\n' "$OUTPUT"
          note_key=$(printf '%s\n' "$OUTPUT" | awk -F': ' '/^PULL_RESULT:/{print $2; exit}')
          note=""
          case "$note_key" in
            updated) note="updated" ;;
            no_updates) note="no changes" ;;
            skipped_read_only) note="skipped (read-only)" ;;
            missing_repo) note="missing repo" ;;
            missing_git) note="missing .git" ;;
            cannot_access_repo) note="cannot access repo" ;;
            pull_failed) note="git pull failed" ;;
            stash_pop_failed) note="stash pop failed" ;;
            *) note="$note_key" ;;
          esac
          if [ $status -eq 0 ]; then
            if [ -z "$note" ]; then
              note="updated"
            fi
            record_result "$SHORT" "$host" "$status" "$note"
            : >"$PULL_OUTPUT_FILE"
          else
            [ -z "$note" ] && note="git pull failed"
            note="$note (exit $status)"
            echo "Error: git pull failed on $host (exit code $status). Continuing to next host."
            printf '%s\n' "$OUTPUT" >"$PULL_OUTPUT_FILE"
            record_result "$SHORT" "$host" "$status" "$note"
          fi
          ;;
        stats)
          echo "Running: collect coach metrics via template API"
          OUTPUT=$(ssh "${SSH_OPTS[@]}" "$ssh_target" "bash -l -c '$CMD'" 2>&1)
          status=$?
          if [ $status -eq 0 ]; then
            if command -v jq >/dev/null 2>&1; then
              if printf '%s\n' "$OUTPUT" | jq empty >/dev/null 2>&1; then
                printf '%s\n' "$OUTPUT" | jq -c .
              else
                printf '%s\n' "$OUTPUT"
                echo "jq parse failed; raw response shown" >&2
              fi
            else
              printf '%s\n' "$OUTPUT"
            fi
            record_result "$SHORT" "$host" "$status" "ok"
          else
            printf '%s\n' "$OUTPUT"
            record_result "$SHORT" "$host" "$status" ""
          fi
          ;;
        *)
          echo "Running: $CMD"
          ssh -t "${SSH_OPTS[@]}" "$ssh_target" "bash -l -c '$CMD'"
          status=$?
          if [ $status -ne 0 ]; then
            echo "Error: Failed to run '$CMD' on $host (exit code $status). Continuing to next host."
          fi
          record_result "$SHORT" "$host" "$status" ""
          ;;
      esac
      if [ $status -ne 0 ]; then
        host_exit=$status
        progress_line fail "$(printf '%s: command %d/%d failed (exit %d)' "$host" "$human_idx" "$total_cmds" "$status")"
      else
        progress_line success "$(printf '%s: command %d/%d completed' "$host" "$human_idx" "$total_cmds")"
      fi
      echo "------------------------------"
    done
    echo ""
  } >"$output_file" 2>&1

  unset RESULTS_FILE
  unset PULL_OUTPUT_FILE

  if [ -n "$notify_fifo" ]; then
    printf '%s|%s|%d\n' "$host_index" "$host" "$host_exit" >"$notify_fifo"
  fi

  return $host_exit
}

process_host_results() {
  local host_index="$1"
  local result_file="$2"
  local pull_output_file="$3"
  local line
  local short
  local host
  local status
  local message

  if [ ! -f "$result_file" ]; then
    return
  fi

  while IFS= read -r line; do
    [ -z "$line" ] && continue
    process_result_line "$line"
    IFS='|' read -r short host status message <<<"$line"
    if [ "$short" = "pull" ]; then
      if [ "$status" -eq 0 ]; then
        PULL_SUCCESSES+=("$host")
      else
        PULL_FAILURES+=("$host")
        if [ -f "$pull_output_file" ] && [ -s "$pull_output_file" ]; then
          PULL_FAILURE_LOGS+=("$(cat "$pull_output_file")")
        else
          PULL_FAILURE_LOGS+=("")
        fi
      fi
    fi
  done <"$result_file"
}

# Host selection
HOSTS=("${ALL_HOSTS[@]}")
HOST_FILTER=""
ARGS=("$@")
if [ "$1" = "--host" ]; then
  if [ $# -lt 3 ]; then
    echo "Error: --host requires a pattern and at least one command."
    usage
  fi
  HOST_FILTER="$2"
  ARGS=("${@:3}")
  HOST_FILTER_LOWER=$(printf '%s' "$HOST_FILTER" | tr '[:upper:]' '[:lower:]')
  if [ "$HOST_FILTER_LOWER" = "all" ]; then
    HOSTS=("${ALL_HOSTS[@]}")
  else
    FILTERED_HOSTS=()
    for h in "${ALL_HOSTS[@]}"; do
      if [[ "$h" == *"$HOST_FILTER"* ]]; then
        FILTERED_HOSTS+=("$h")
      fi
    done
    if [ ${#FILTERED_HOSTS[@]} -eq 0 ]; then
      echo "No hosts match pattern: $HOST_FILTER"
      exit 1
    elif [ ${#FILTERED_HOSTS[@]} -gt 1 ]; then
      echo "Multiple hosts match pattern: $HOST_FILTER"
      for h in "${FILTERED_HOSTS[@]}"; do
        echo "  $h"
      done
      echo "Please specify a more precise host."
      exit 1
    fi
    HOSTS=("${FILTERED_HOSTS[0]}")
  fi
fi

if [ ${#ARGS[@]} -eq 0 ]; then
  echo "Error: No command specified."
  usage
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

progress_line info "$(printf 'Preparing %d command(s) for %d host(s)' "${#SHORTS_TO_RUN[@]}" "${#HOSTS[@]}")"

INTERACTIVE_MODE=0
INTERACTIVE_SHORT=""
for short_name in "${SHORTS_TO_RUN[@]}"; do
  if [ "$short_name" = "ssh" ] || [ "$short_name" = "docker" ]; then
    INTERACTIVE_MODE=1
    INTERACTIVE_SHORT="$short_name"
    break
  fi
done

if [ $INTERACTIVE_MODE -eq 1 ]; then
  if [ ${#SHORTS_TO_RUN[@]} -ne 1 ]; then
    echo "Error: The '$INTERACTIVE_SHORT' command must be run alone."
    exit 1
  fi
  if [ ${#HOSTS[@]} -ne 1 ]; then
    echo "Error: The '$INTERACTIVE_SHORT' command requires exactly one host (use --host to specify)."
    exit 1
  fi
  HOST="${HOSTS[0]}"
  SSH_TARGET="${SSH_USER}@${HOST}"
  echo "=============================="
  echo "Connecting to $HOST"
  echo "=============================="
  progress_line start "$(printf 'Host %s: establishing interactive session' "$HOST")"
  if [ "$INTERACTIVE_SHORT" = "ssh" ]; then
    echo "Opening interactive SSH session to $HOST..."
    ssh "${SSH_OPTS[@]}" "$SSH_TARGET"
    status=$?
    if [ $status -ne 0 ]; then
      echo "Error: SSH connection to $HOST failed (exit code $status)."
      progress_line fail "$(printf 'Host %s: SSH session failed (exit %d)' "$HOST" "$status")"
    else
      progress_line success "$(printf 'Host %s: SSH session ended' "$HOST")"
    fi
    record_result "$INTERACTIVE_SHORT" "$HOST" "$status" ""
    print_summary
    exit $status
  else
    echo "Running docker_shell.sh on $HOST..."
    ssh -t "${SSH_OPTS[@]}" "$SSH_TARGET" "bash /config/docker_shell.sh"
    status=$?
    if [ $status -ne 0 ]; then
      echo "Error: Docker shell on $HOST failed (exit code $status)."
      progress_line fail "$(printf 'Host %s: docker shell failed (exit %d)' "$HOST" "$status")"
    else
      progress_line success "$(printf 'Host %s: docker shell session ended' "$HOST")"
    fi
    record_result "$INTERACTIVE_SHORT" "$HOST" "$status" ""
    print_summary
    exit $status
  fi
fi

HOST_COUNT=${#HOSTS[@]}
if [ "$HOST_COUNT" -eq 0 ]; then
  echo "No hosts selected."
  exit 1
fi

TEMP_DIR=$(mktemp -d 2>/dev/null || mktemp -d -t ha_multi_host.XXXXXX)
if [ ! -d "$TEMP_DIR" ]; then
  echo "Error: Unable to create temporary directory for host execution."
  exit 1
fi

if [ "$HOST_COUNT" -eq 1 ]; then
  host="${HOSTS[0]}"
  output_file="$TEMP_DIR/host_0_output.log"
  result_file="$TEMP_DIR/host_0_results.log"
  pull_file="$TEMP_DIR/host_0_pull.log"
  progress_line start "$(printf 'Host %s: queued for execution' "$host")"
  if run_commands_for_host 0 "$host" "$output_file" "$result_file" "$pull_file" ""; then
    progress_line success "$(printf 'Host %s: completed (1/1)' "$host")"
  else
    progress_line fail "$(printf 'Host %s: failed (1/1)' "$host")"
    OVERALL_EXIT=1
  fi
  cat "$output_file"
  process_host_results 0 "$result_file" "$pull_file"
else
  fifo="$TEMP_DIR/notify.fifo"
  if ! mkfifo "$fifo"; then
    echo "Error: Unable to create coordination FIFO."
    rm -rf "$TEMP_DIR"
    exit 1
  fi

  exec 3<>"$fifo"
  HOST_OUTPUT_FILES=()
  HOST_RESULT_FILES=()
  HOST_PULL_FILES=()
  HOST_PIDS=()

  for idx in "${!HOSTS[@]}"; do
    host="${HOSTS[$idx]}"
    output_file="$TEMP_DIR/host_${idx}_output.log"
    result_file="$TEMP_DIR/host_${idx}_results.log"
    pull_file="$TEMP_DIR/host_${idx}_pull.log"
    HOST_OUTPUT_FILES[$idx]="$output_file"
    HOST_RESULT_FILES[$idx]="$result_file"
    HOST_PULL_FILES[$idx]="$pull_file"
    progress_line start "$(printf 'Host %s: queued for execution' "$host")"
    run_commands_for_host "$idx" "$host" "$output_file" "$result_file" "$pull_file" "$fifo" &
    HOST_PIDS[$idx]=$!
  done

  hosts_remaining=$HOST_COUNT
  hosts_completed=0
  while [ $hosts_remaining -gt 0 ]; do
    if ! IFS='|' read -r host_index host_name host_status <&3; then
      break
    fi
    pid="${HOST_PIDS[$host_index]}"
    if wait "$pid"; then
      wait_status=0
    else
      wait_status=$?
    fi
    if [ "$wait_status" -ne 0 ] || [ "$host_status" -ne 0 ]; then
      OVERALL_EXIT=1
    fi
    hosts_completed=$(( hosts_completed + 1 ))
    if [ "$host_status" -eq 0 ] && [ "$wait_status" -eq 0 ]; then
      progress_line success "$(printf 'Host %s: completed (%d/%d)' "$host_name" "$hosts_completed" "$HOST_COUNT")"
    else
      progress_line fail "$(printf 'Host %s: failed (%d/%d)' "$host_name" "$hosts_completed" "$HOST_COUNT")"
    fi
    cat "${HOST_OUTPUT_FILES[$host_index]}"
    process_host_results "$host_index" "${HOST_RESULT_FILES[$host_index]}" "${HOST_PULL_FILES[$host_index]}"
    hosts_remaining=$(( hosts_remaining - 1 ))
  done
  exec 3>&-
  rm -f "$fifo"
fi

if [ -n "$TEMP_DIR" ] && [ -d "$TEMP_DIR" ]; then
  rm -rf "$TEMP_DIR"
fi

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
