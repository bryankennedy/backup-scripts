### INFRA-78 — Select the duplicacy storage by name, not by renaming it

*Decided 2026-10-26.*

The vault's first duplicacy storage was set up without encryption. Duplicacy cannot encrypt a storage in place, so the owner adds a second, encrypted storage, copies the revisions to it and then deletes the old chunks.

`obsidian.sh` now passes `-storage "$DUPLICACY_STORAGE"` to `backup` and `prune` when `.env` sets that value. When the value is empty, the script passes no `-storage` flag, and duplicacy uses the first storage in its preferences. Without a `.env` setting, the script behaves as before. After the old storage is removed from the preferences, the encrypted storage is the first one, so a lost `.env` does not stop the backup.

We did not rename the new storage to `default` in the preferences file. Duplicacy keys its saved keychain entries and its environment variables by the storage name, so a rename makes duplicacy ask for the passwords again. A prompt in an unattended cron run stops the backup.

The storage password stays in the macOS keychain and in 1Password. It is never in `.env`, because `.env` is a plaintext file.

The new storage is created with `add -e -copy` from the unencrypted one, so the copy keeps the same chunk boundaries. Duplicacy then inherits the default chunk seed and hash key. The chunk contents and the chunk IDs use random keys and stay protected. Only the chunk boundaries are predictable. We accept this, because `copy` needs compatible storages to keep the revision history.

The migration and the cleanup are owner steps on the machine that holds the vault. The runbook is a comment on INFRA-78 in Progress.
