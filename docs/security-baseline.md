# Security audit baseline

This file records findings that were reviewed and accepted. The nightly review reads it, stays quiet about what is here, and so a new finding stands out.

Rules:

- An entry here is not re-reported. It is **re-verified**: if its conditions no longer hold, the review says so.
- Every entry carries the date it was accepted and why the risk is tolerable. "Looked fine" is not a reason.
- Never baseline a live secret. Rotate it, then scrub it.

---

## Accepted — exposure

### A commit message names the backup's former storage bucket
*Accepted 2026-09-11. Coordinates are in the owner's private findings file.*

One commit message in this repository's history names the cloud storage bucket the backup script used to write to. It also gives a snapshot revision and the dates the backup was not running. Bucket names share one global namespace, so a published name can be probed directly.

It is accepted, not rewritten, because the name no longer leads anywhere. The backup moved to a new bucket whose name has never been published, and the named bucket was emptied. That bucket was kept, not deleted: deleting it would free the name for anyone to create, and any stale configuration would then upload into their bucket. Both buckets refuse public access. A force-push would not have removed the commit from copies GitHub already serves, and the outage it describes is over.

**Re-verify, do not re-decide.** This expires if the named bucket is deleted or holds objects again, or if the new bucket's name appears anywhere in this repository. That name belongs only in the local duplicacy configuration inside the backed-up folder, which this repository does not track.

## Accepted — encryption

### The encrypted storage keeps the default chunk seed and hash key
*Accepted 2026-11-04 (INFRA-329). The trade-off is in `docs/decisions/INFRA-78.md`.*

The owner made the encrypted storage with `add -e -copy` from the unencrypted one, so that `copy` keeps the revision history. Duplicacy then keeps the default chunk seed and hash key. The chunk contents and the chunk IDs use random keys and stay protected: without `-bit-identical`, `-copy` keeps only the chunk seed and the hash key, and the ID key stays random (checked in Duplicacy's `duplicacy_config.go` on 2026-11-04). So the chunk file names do not show what a chunk holds. Only the chunk boundaries are predictable. Someone who can read the chunk files can use the boundaries to test whether the backup holds a file they already have. The decision record says this in public.

Accepted because nobody but the owner can read the chunk files. The owner confirmed on 2026-11-04 that every resource on this path is private:

- The storage that holds the chunks refuses public access, and its coordinates are not in this repository.
- The storage password is in the macOS keychain and in 1Password. It is never in this repository or in `.env`.
- The backed-up vault and the local Duplicacy configuration stay on the owner's machine, outside this repository.

So an attacker must first get read access to a private storage. The predictable boundaries then show at most whether a known file is in the backup. They show no file content.

**Re-verify, do not re-decide.** This expires if:

- any storage that holds these chunks allows public or shared read access;
- the storage password, or the storage coordinates, appear in this repository or in `.env`;
- a storage that holds these chunks was made with `-bit-identical`, which copies the ID key too and makes the chunk file names predictable.

Retire this entry if the owner makes a new encrypted storage with its own random chunk seed, for example with `add -e` and a fresh first backup instead of `-copy`.
