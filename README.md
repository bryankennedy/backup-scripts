# Obsidian Backup Script

A simple bash script to backup an [Obsidian](https://obsidian.md) Vault using [Duplicacy](https://duplicacy.com/).

## Features
- **Automated Backups**: Designed to run hourly from `launchd` on macOS.
- **Daily Frequency**: Ensures backups only happen once every 24 hours, even if the script is called more often.
- **Retention Policy**: Automatically prunes old backups (Grandfather-Father-Son strategy).
- **Storage Check**: Runs `duplicacy check` after every backup, so a revision with a missing chunk fails the run.
- **Loud Failure**: A failed step exits with duplicacy's exit code, logs `Backup Failed`, and does not stamp the cooldown. The next hourly slot retries.
- **Logging**: Tracks runs in `logs/obsidian_backup.log`.

## Setup

1. Ensure `duplicacy` is installed at `/usr/local/bin/duplicacy`.
2. Make the script executable:
   ```bash
   chmod +x obsidian.sh
   ```
3. Optional: copy `.env.example` to `.env`. Set `DUPLICACY_STORAGE` to back up to, prune and check a storage other than the first one in `.duplicacy/preferences`. Set `TARGET_FOLDER` or `DUPLICACY_PATH` if your paths differ from the defaults in the script. Keep storage passwords in the keychain, not in `.env`.
4. Schedule the hourly run with `launchd`. See the next section.

## Schedule with launchd

Run the script from a `launchd` user agent, not from `cron`. A user agent runs inside your login session, so duplicacy can read the storage password from the login keychain. A `cron` job runs outside that session. Under `cron`, duplicacy cannot read the keychain, prompts for the password, and fails with `Enter storage password:Failed to read the password: EOF`.

The template is `launchd/dev.bck.obsidian-backup.plist.example`. It runs the script at minute 0 of every hour. The script keeps its own 24-hour cooldown, so one run per day uploads. After the machine wakes from sleep, `launchd` runs a missed slot once.

### Install

Run these commands from the root of this repository. The `sed` command puts the absolute path of this clone into the template. If that path holds `#`, `&` or a backslash, edit the file by hand instead.

```bash
mkdir -p logs
sed "s#__CLONE__#$PWD#g" launchd/dev.bck.obsidian-backup.plist.example > ~/Library/LaunchAgents/dev.bck.obsidian-backup.plist
plutil -lint ~/Library/LaunchAgents/dev.bck.obsidian-backup.plist
```

Expected: `OK`.

### Remove the cron line

Before you load the agent, remove the hourly `obsidian.sh` line from your crontab. If both schedulers run the script, two backups can start at the same minute. The first command saves a copy of the crontab.

```bash
crontab -l > ~/crontab.bak
grep -v 'obsidian.sh' ~/crontab.bak | crontab -
crontab -l | grep 'obsidian.sh'
```

Expected: no output from the last command.

### Load

```bash
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/dev.bck.obsidian-backup.plist
```

If an older copy of the agent is loaded, run the unload command first.

### Verify

```bash
launchctl print gui/$(id -u)/dev.bck.obsidian-backup | grep -E 'state|last exit'
```

Expected: `state = not running` between runs. The exit code is `(never exited)` before the first run and `0` after a passing run. A failed backup, prune or check exits with duplicacy's exit code, which is `100` for most errors. On a failure, read the log.

To run the job now and not wait for the next hour:

```bash
launchctl kickstart gui/$(id -u)/dev.bck.obsidian-backup
```

Then check the log. The run either uploads, logs a cooldown skip, or logs a failure.

```bash
grep -E 'Backup Started|Backup Skipped|Backup Failed|Backup Finished|ERROR|password|revision [0-9]+ completed|are missing' logs/obsidian_backup.log | tail -6
```

Expected: a `Backup Started` line, a `revision N completed` line and a `Backup Finished` line, or a `Backup Skipped` line. There must be no `Backup Failed`, `ERROR`, `password` or `are missing` line. `logs/launchd.log` holds the script's own output, for example `Backup uploaded` or `Backup failed at step 'check'`.

A failed run does not write the cooldown stamp, so the job retries at the next hour and logs the failure again. Fix the cause, then run the job by hand with `./obsidian.sh --force` to confirm.

### Unload

```bash
launchctl bootout gui/$(id -u)/dev.bck.obsidian-backup
```

The plist file stays in `~/Library/LaunchAgents/`. Delete it to remove the agent permanently.

## Usage
Run manually to check status:
```bash
./obsidian.sh
```
The output says whether the backup was uploaded, skipped because of the cooldown, or failed at the backup, prune or check step. The exit code is `0` for an upload or a skip and duplicacy's exit code for a failure.

## Test
```bash
bun test
```
The tests run `obsidian.sh` against a fake duplicacy in a temp dir, and hold the `.gitignore` rule in place. They need no network and no storage.
