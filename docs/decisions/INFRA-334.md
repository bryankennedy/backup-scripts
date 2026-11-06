### INFRA-334 — Check the storage in the job, and stamp the cooldown only on success

*Decided 2026-11-06. Closes INFRA-61.*

On 2026-10-31 the job logged `revision 160 completed`, but one of the four new chunks of that revision never reached the storage. The next five daily runs did not notice. A `duplicacy check` that the owner ran by hand on 2026-11-06 found it, and revisions 160 and 161 had to be removed. The job must find this itself.

`obsidian.sh` now runs three steps in order: `backup`, `prune`, `check -a`. Each step must exit 0 for the next one to run. A failed step writes a `Backup Failed` line with the step name and the exit code to the log, prints one line to stderr, and exits with duplicacy's exit code. The script prints `Backup uploaded` only after the check passes.

The cooldown stamp moves to the end of a passing run. Before, the script wrote the stamp before the backup started (INFRA-61), so a failed run stayed silent for a day. Now a failed run leaves the old stamp alone, and the next hourly `launchd` slot retries. A persistent failure logs once an hour, which is the loud failure this decision wants. The stamp holds the start time of the run, not the end time, so the length of the run does not push the next slot later each day.

We put the check after the prune, not before it. The prune can fossilize chunks, and a check before the prune would pass on a chunk the prune then removes. The check runs on the state the next backup will build on.

We did not add a `-fossils` flag to the check. The job is the only client of the storage, so a chunk that a snapshot still references is never a fossil after the prune in the same run.

`TARGET_FOLDER` and `DUPLICACY_PATH` can now come from `.env`. The defaults in the script are unchanged. The test suite uses this to run the script against a fake duplicacy in a temp dir, and proves the exit codes and the cooldown rules without a storage.
