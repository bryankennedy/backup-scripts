# AGENTS.md

A small bash script that backs up an Obsidian vault with Duplicacy to cloud
object storage. It is meant to be run hourly from launchd on the owner's
machine; the script enforces a 24-hour cooldown itself, then uploads, prunes
old revisions on a grandfather-father-son schedule, and checks the storage.
`README.md` has the setup and usage; this file does not repeat it.

This repository is **public**. Do not write hostnames, bucket names, account
emails, IPs or paths specific to one machine into any file, commit message or
PR. Storage coordinates live in the local Duplicacy configuration inside the
backed-up folder, which this repository does not track.

## Commands

- `./obsidian.sh` runs a backup, a prune and a check (skipped if a run
  passed in the last 24 hours); `./obsidian.sh --force` ignores the cooldown.
  A failed step exits with duplicacy's exit code and leaves the cooldown
  stamp alone.
- `bun test` runs `tests/script.test.js`, which drives `obsidian.sh` against
  a fake duplicacy in a temp dir, and `tests/hygiene.test.js`, which holds
  the single-root `.gitignore` rule in place. There are no dependencies to
  install.

## Constraints

- `obsidian.sh` loads an optional `.env` next to it; `.env`, logs and the
  cooldown timestamp file are git-ignored and must stay that way.
- `docs/security-baseline.md` lists reviewed, accepted findings. The nightly
  security review reads it; add an entry only with a date and a reason, and
  never baseline a live secret.

Fleet policy lives in infrastructure's [docs/house-standards.md](https://git.bck.dev/bkennedy/infrastructure/src/branch/main/docs/house-standards.md); it is linked here, not restated.
