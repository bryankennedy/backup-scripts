# Obsidian Backup Script

A simple bash script to backup an [Obsidian](https://obsidian.md) Vault using [Duplicacy](https://duplicacy.com/).

## Features
- **Automated Backups**: Designed to run hourly from `launchd` on macOS.
- **Daily Frequency**: Ensures backups only happen once every 24 hours, even if the script is called more often.
- **Retention Policy**: Automatically prunes old backups (Grandfather-Father-Son strategy).
- **Logging**: Tracks runs in `logs/obsidian_backup.log`.

## Setup

1. Ensure `duplicacy` is installed at `/usr/local/bin/duplicacy`.
2. Make the script executable:
   ```bash
   chmod +x obsidian.sh
   ```
3. Optional: copy `.env.example` to `.env`. Set `DUPLICACY_STORAGE` to back up to and prune a storage other than the first one in `.duplicacy/preferences`. Keep storage passwords in the keychain, not in `.env`.
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

Expected: `state = not running` between runs. The exit code is `(never exited)` before the first run and `0` after it. The exit code only shows that the script ran. The script does not pass on duplicacy's exit code yet, so read the log to see the result.

To run the job now and not wait for the next hour:

```bash
launchctl kickstart gui/$(id -u)/dev.bck.obsidian-backup
```

Then check the log. The run either uploads or logs a cooldown skip.

```bash
grep -E 'Backup Started|Backup Skipped|ERROR|password|revision [0-9]+ completed' logs/obsidian_backup.log | tail -5
```

Expected: a `Backup Started` line and then a `revision N completed` line, or a `Backup Skipped` line. There must be no `ERROR` line and no `password` line. `logs/launchd.log` holds the script's own output, for example `Backup uploaded`.

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
Output will indicate if a backup was uploaded or skipped due to the cooldown.
