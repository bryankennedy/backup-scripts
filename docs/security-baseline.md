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

### A commit message says the backup's storage is not encrypted
*Accepted 2026-11-06 (INFRA-280).*

The message of commit `3baa66d` says, in the present tense, that the vault's duplicacy storage is not encrypted. That was true on 2026-10-26, when the commit was made. It stopped being true on 2026-11-06, when the owner deleted the plaintext chunks, snapshots and config from the bucket (INFRA-281). Only the encrypted storage remains, and the local duplicacy preferences list only that storage. `docs/decisions/INFRA-78.md` records the cutover in the past tense.

It is accepted, not rewritten, because published history cannot be rewritten, and the text no longer describes anything that exists. The bucket name is not in the message. The bucket refuses public access, which the owner checked on 2026-11-06.

**Re-verify, do not re-decide.** This expires if an unencrypted storage for this backup holds objects again, or if a document in this repository says the live storage is unencrypted in the present tense.

## Accepted — encryption

### The encrypted storage was made from the unencrypted one
*Accepted 2026-11-04 (INFRA-329). The detail and the conditions are in the owner's private findings file (INFRA-332).*

The owner made the encrypted storage from the first, unencrypted one, so that the revision history stays. That leaves a known, limited weakness. The owner accepted it, because every resource on this path is private.

**Re-verify, do not re-decide.** This expires if:

- any storage that holds this backup allows public or shared access;
- a secret or a storage location for this backup appears in this repository or in `.env`.

The other conditions, and when to retire this entry, are in the owner's private findings file.
