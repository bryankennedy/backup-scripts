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
