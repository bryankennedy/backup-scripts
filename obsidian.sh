#!/bin/bash
# Back up the Obsidian vault with duplicacy, prune old revisions, then check
# the storage. The run passes only when all three steps exit 0. The 24-hour
# cooldown stamp is written at the end of a passing run, so a failed run
# retries at the next hourly slot instead of staying silent for a day
# (INFRA-61, INFRA-334).

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load environment variables
if [ -f "$SCRIPT_DIR/.env" ]; then
    set -a
    source "$SCRIPT_DIR/.env"
    set +a
fi

# Check for force flag
FORCE_RUN=false
if [[ "$1" == "--force" ]]; then
    FORCE_RUN=true
    echo "Force flag detected. Ignoring cooldown."
fi

# Configuration. .env can set TARGET_FOLDER and DUPLICACY_PATH; these are the
# defaults for the owner's machine.
TARGET_FOLDER="${TARGET_FOLDER:-$HOME/Obsidian/cephalalgic}"
DUPLICACY_PATH="${DUPLICACY_PATH:-/opt/homebrew/bin/duplicacy}"
# Duplicacy storage to back up to, prune and check, from DUPLICACY_STORAGE in
# .env. When it is empty, duplicacy uses the first storage in its preferences
# (INFRA-78).
STORAGE_ARGS=()
if [ -n "$DUPLICACY_STORAGE" ]; then
    STORAGE_ARGS=(-storage "$DUPLICACY_STORAGE")
fi
LOG_FILE="$SCRIPT_DIR/logs/obsidian_backup.log"
TIMESTAMP_FILE="$SCRIPT_DIR/obsidian_last_run.txt"

# Create log directory if it doesn't exist
mkdir -p "$(dirname "$LOG_FILE")"

# Check if we should run the backup (24 hour cooldown)
START_TIME=$(date +%s)
if [ "$FORCE_RUN" = false ] && [ -f "$TIMESTAMP_FILE" ]; then
    LAST_RUN=$(cat "$TIMESTAMP_FILE")
    # Simple validation to ensure LAST_RUN is a number
    if [[ "$LAST_RUN" =~ ^[0-9]+$ ]]; then
        DIFF=$((START_TIME - LAST_RUN))
        if [ $DIFF -lt 86400 ]; then
            # Less than 24 hours since last run
            REMAINING=$(( (86400 - DIFF) / 3600 ))
            echo "--- Backup Skipped: $(date) --- (Cooldown active, ~$REMAINING hours remaining)" >> "$LOG_FILE"
            echo "Backup skipped until tomorrow"
            exit 0
        fi
    fi
fi

if ! cd "$TARGET_FOLDER"; then
    echo "--- Backup Failed: $(date) --- (vault folder not found: $TARGET_FOLDER)" >> "$LOG_FILE"
    echo "Backup failed: vault folder not found: $TARGET_FOLDER" >&2
    exit 1
fi
echo "--- Backup Started: $(date) ---" >> "$LOG_FILE"

# Log the failed step, tell the caller, and exit with duplicacy's exit code.
# The cooldown stamp is not written, so the next hourly slot retries.
fail() {
    local step=$1 code=$2
    echo "--- Backup Failed: $(date) --- (step: $step, exit code: $code)" >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"
    echo "Backup failed at step '$step' (exit code $code). See $LOG_FILE" >&2
    exit "$code"
}

# STEP 1: RUN THE BACKUP
# This uploads changes to the storage
"$DUPLICACY_PATH" backup "${STORAGE_ARGS[@]}" -stats >> "$LOG_FILE" 2>&1 || fail backup $?

# STEP 2: APPLY RETENTION POLICY (Grandfather-Father-Son)
# This deletes old backups to keep your storage small.
# Rules are applied from "Oldest" to "Newest":
# -keep 30:100 -> If older than 100 days, keep 1 backup every 30 days (Monthly)
# -keep 7:30   -> If older than 30 days, keep 1 backup every 7 days (Weekly)
# -keep 1:1    -> If older than 1 day, keep 1 backup every 1 day (Daily)
"$DUPLICACY_PATH" prune "${STORAGE_ARGS[@]}" -keep 30:100 -keep 7:30 -keep 1:1 -a >> "$LOG_FILE" 2>&1 || fail prune $?

# STEP 3: CHECK THE STORAGE
# This confirms that every chunk each revision references exists in the
# storage. On 2026-10-31 a backup logged a revision as complete while one of
# its chunks never reached the storage; nothing noticed for six days
# (INFRA-334). A missing chunk now fails the run.
"$DUPLICACY_PATH" check "${STORAGE_ARGS[@]}" -a >> "$LOG_FILE" 2>&1 || fail check $?

# All three steps passed. Stamp the cooldown with the start time, so the
# length of the run does not push the next slot later each day.
echo "$START_TIME" > "$TIMESTAMP_FILE"
echo "--- Backup Finished: $(date) ---" >> "$LOG_FILE"
echo "Backup uploaded"
echo "" >> "$LOG_FILE"
