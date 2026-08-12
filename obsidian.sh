#!/bin/bash
# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load environment variables
if [ -f "$SCRIPT_DIR/.env" ]; then
    set -a
    source "$SCRIPT_DIR/.env"
    set +a
fi

# Configuration
TARGET_FOLDER="$HOME/Desktop/Obsidian Vault"
DUPLICACY_PATH="/usr/local/bin/duplicacy"
LOG_FILE="$SCRIPT_DIR/logs/obsidian_backup.log"
TIMESTAMP_FILE="$SCRIPT_DIR/obsidian_last_run.txt"

# Create log directory if it doesn't exist
mkdir -p "$(dirname "$LOG_FILE")"

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
            echo "Backup skipped until tomorrow"
            exit 0
        fi
    fi
fi

# Update the timestamp
date +%s > "$TIMESTAMP_FILE"

cd "$TARGET_FOLDER" || exit
echo "--- Backup Started: $(date) ---" >> "$LOG_FILE"

# STEP 1: RUN THE BACKUP
# This uploads changes to Google Cloud
$DUPLICACY_PATH backup -stats >> "$LOG_FILE" 2>&1

# STEP 2: APPLY RETENTION POLICY (Grandfather-Father-Son)
# This deletes old backups to keep your storage small.
# Rules are applied from "Oldest" to "Newest":
# -keep 30:100 -> If older than 100 days, keep 1 backup every 30 days (Monthly)
# -keep 7:30   -> If older than 30 days, keep 1 backup every 7 days (Weekly)
# -keep 1:1    -> If older than 1 day, keep 1 backup every 1 day (Daily)
$DUPLICACY_PATH prune -keep 30:100 -keep 7:30 -keep 1:1 -a >> "$LOG_FILE" 2>&1

echo "--- Backup Finished: $(date) ---" >> "$LOG_FILE"
echo "Backup uploaded"
echo "" >> "$LOG_FILE"