### INFRA-78 — Select the duplicacy storage by name, not by renaming it

*Decided 2026-10-26.*

The vault's first duplicacy storage was set up without encryption. Duplicacy cannot encrypt a storage in place, so the owner adds a second, encrypted storage, copies the revisions to it and then deletes the old chunks.

`obsidian.sh` now passes `-storage "$DUPLICACY_STORAGE"` to `backup` and `prune` when `.env` sets that value. When the value is empty, the script passes no `-storage` flag, and duplicacy uses the first storage in its preferences. Without a `.env` setting, the script behaves as before. After the old storage is removed from the preferences, the encrypted storage is the first one, so a lost `.env` does not stop the backup.

We did not rename the new storage to `default` in the preferences file. Duplicacy keys its saved keychain entries and its environment variables by the storage name, so a rename makes duplicacy ask for the passwords again. A prompt in an unattended cron run stops the backup.

The storage password stays in the macOS keychain and in 1Password. It is never in `.env`, because `.env` is a plaintext file.

The new storage is created with `add -e -copy` from the unencrypted one, so the copy keeps the same chunk boundaries. Duplicacy then inherits the default chunk seed and hash key. The chunk contents and the chunk IDs use random keys and stay protected. Only the chunk boundaries are predictable. We accept this, because `copy` needs compatible storages to keep the revision history.

The migration and the cleanup are owner steps on the machine that holds the vault. The runbook is a comment on INFRA-78 in Progress.

### INFRA-78b — Run the backup from launchd, not cron

*Decided 2026-10-30.*

The encrypted storage has a password. Duplicacy saves it in the login keychain, and a Terminal run reads it from there. A `cron` job runs outside the login session. Under `cron`, the keychain lookup returns "item not found" (error -25300), duplicacy prompts for the password, and the run fails with "Failed to read the password: EOF". The failed run still stamps the 24-hour cooldown (INFRA-61), so the job then stays silent for a day.

A `launchd` user agent in the `gui/<uid>` domain runs inside the login session. A test agent ran `obsidian.sh --force` and completed a backup with no prompt and exit code 0. So the repository now ships a LaunchAgent template, `launchd/dev.bck.obsidian-backup.plist.example`, and the README replaces the `cron` line with install, load, verify and unload steps.

We did not put the password in `.env` or in the plist. Both are plaintext files, and the plist would also hold it in a world-readable directory. We did not use `DUPLICACY_ENCRYPTED_PASSWORD` for the same reason. The password stays in the keychain and in 1Password.

The template uses `StartCalendarInterval` with `Minute 0`, the same cadence as the old `cron` line. The script keeps its own cooldown, so the change does not alter how often a backup uploads. `launchd` runs a missed slot once after wake, which `cron` does not do.

The template has one placeholder, `__CLONE__`, for the path of the clone. It holds no hostname, bucket name or account. The installed plist lives in `~/Library/LaunchAgents/`, outside the repository.
