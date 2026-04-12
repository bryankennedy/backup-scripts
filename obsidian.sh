#!/bin/bash
# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Configuration
TARGET_FOLDER="$HOME/Desktop/Obsidian Vault"
DUPLICACY_PATH="/usr/local/bin/duplicacy"
LOG_FILE="$SCRIPT_DIR/logs/obsidian_backup.log"
TIMESTAMP_FILE="$SCRIPT_DIR/obsidian_last_run.txt"

# PostHog Configuration
# Set POSTHOG_API_KEY in your environment or in a .env file next to this script.
# Example .env:
#   POSTHOG_API_KEY=phc_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
if [ -f "$SCRIPT_DIR/.env" ]; then
    # shellcheck disable=SC1091
    source "$SCRIPT_DIR/.env"
fi
POSTHOG_API_KEY="${POSTHOG_API_KEY:-}"
POSTHOG_HOST="${POSTHOG_HOST:-https://us.i.posthog.com}"
POSTHOG_DISTINCT_ID="${HOSTNAME:-obsidian-backup}"

# Create log directory if it doesn't exist
mkdir -p "$(dirname "$LOG_FILE")"

# Send an event to PostHog. Silently skipped if POSTHOG_API_KEY is not set.
# Usage: posthog_capture <event_name> <json_properties>
posthog_capture() {
    local event="$1"
    local properties="${2:-\{\}}"

    if [ -z "$POSTHOG_API_KEY" ]; then
        return 0
    fi

    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    local payload
    payload=$(printf '{"api_key":"%s","event":"%s","distinct_id":"%s","timestamp":"%s","properties":%s}' \
        "$POSTHOG_API_KEY" "$event" "$POSTHOG_DISTINCT_ID" "$timestamp" "$properties")

    curl -s --max-time 10 \
        -H "Content-Type: application/json" \
        -d "$payload" \
        "$POSTHOG_HOST/capture/" >> "$LOG_FILE" 2>&1 || true
}

# Check if we should run the backup (24 hour cooldown)
if [ -f "$TIMESTAMP_FILE" ]; then
    LAST_RUN=$(cat "$TIMESTAMP_FILE")
    CURRENT_TIME=$(date +%s)
    # Simple validation to ensure LAST_RUN is a number
    if [[ "$LAST_RUN" =~ ^[0-9]+$ ]]; then
        DIFF=$((CURRENT_TIME - LAST_RUN))
        if [ $DIFF -lt 86400 ]; then
            # Less than 24 hours since last run
            REMAINING=$(( (86400 - DIFF) / 3600 ))
            echo "--- Backup Skipped: $(date) --- (Cooldown active, ~$REMAINING hours remaining)" >> "$LOG_FILE"
            posthog_capture "backup_skipped" \
                "{\"script\":\"obsidian\",\"remaining_hours\":$REMAINING}"
            echo "Backup skipped until tomorrow"
            exit 0
        fi
    fi
fi

# Update the timestamp
date +%s > "$TIMESTAMP_FILE"

cd "$TARGET_FOLDER" || exit
echo "--- Backup Started: $(date) ---" >> "$LOG_FILE"
posthog_capture "backup_started" \
    "{\"script\":\"obsidian\"}"

# STEP 1: RUN THE BACKUP
# This uploads changes to Google Cloud
$DUPLICACY_PATH backup -stats >> "$LOG_FILE" 2>&1
BACKUP_EXIT_CODE=$?

if [ $BACKUP_EXIT_CODE -ne 0 ]; then
    echo "ERROR: Backup step failed with exit code $BACKUP_EXIT_CODE" >> "$LOG_FILE"
    posthog_capture "backup_error" \
        "{\"script\":\"obsidian\",\"step\":\"backup\",\"exit_code\":$BACKUP_EXIT_CODE}"
fi

# STEP 2: APPLY RETENTION POLICY (Grandfather-Father-Son)
# This deletes old backups to keep your storage small.
# Rules are applied from "Oldest" to "Newest":
# -keep 30:100 -> If older than 100 days, keep 1 backup every 30 days (Monthly)
# -keep 7:30   -> If older than 30 days, keep 1 backup every 7 days (Weekly)
# -keep 1:1    -> If older than 1 day, keep 1 backup every 1 day (Daily)
$DUPLICACY_PATH prune -keep 30:100 -keep 7:30 -keep 1:1 -a >> "$LOG_FILE" 2>&1
PRUNE_EXIT_CODE=$?

if [ $PRUNE_EXIT_CODE -ne 0 ]; then
    echo "ERROR: Prune step failed with exit code $PRUNE_EXIT_CODE" >> "$LOG_FILE"
    posthog_capture "backup_error" \
        "{\"script\":\"obsidian\",\"step\":\"prune\",\"exit_code\":$PRUNE_EXIT_CODE}"
fi

echo "--- Backup Finished: $(date) ---" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

if [ $BACKUP_EXIT_CODE -eq 0 ] && [ $PRUNE_EXIT_CODE -eq 0 ]; then
    posthog_capture "backup_completed" \
        "{\"script\":\"obsidian\",\"status\":\"success\"}"
    echo "Backup uploaded"
else
    posthog_capture "backup_completed" \
        "{\"script\":\"obsidian\",\"status\":\"failed\",\"backup_exit_code\":$BACKUP_EXIT_CODE,\"prune_exit_code\":$PRUNE_EXIT_CODE}"
    echo "Backup completed with errors"
fi
