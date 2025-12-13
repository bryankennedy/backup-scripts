# Obsidian Backup Script

A simple bash script to backup an Obsidian Vault using [Duplicacy](https://duplicacy.com/).

## Features
- **Automated Backups**: Designed to run via `cron` hourly.
- **Daily Frequency**: Ensures backups only happen once every 24 hours, even if the script is called more often.
- **Retention Policy**: Automatically prunes old backups (Grandfather-Father-Son strategy).
- **Logging**: Tracks runs in `logs/obsidian_backup.log`.

## Setup

1. Ensure `duplicacy` is installed at `/usr/local/bin/duplicacy`.
2. Make the script executable:
   ```bash
   chmod +x obsidian.sh
   ```
3. Add to crontab to run hourly (the script manages the daily limit):
   ```bash
   0 * * * * /usr/local/src/backup_scripts/obsidian.sh
   ```

## Usage
Run manually to check status:
```bash
./obsidian.sh
```
Output will indicate if a backup was uploaded or skipped due to the cooldown.
