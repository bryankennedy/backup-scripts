// obsidian.sh behaviour, run against a fake duplicacy (INFRA-61, INFRA-334).
//
// The script is copied into a temp dir so it finds no .env, writes its log
// and cooldown stamp there, and never touches the vault or a real storage.
// The fake duplicacy records every call and fails the step named in
// FAKE_DUPLICACY_FAIL. Static, no network, no secrets.
import { test, expect, describe, beforeEach, afterEach } from "bun:test";
import { mkdtempSync, mkdirSync, writeFileSync, readFileSync, existsSync, rmSync, copyFileSync, chmodSync } from "node:fs";
import { join, dirname } from "node:path";
import { tmpdir } from "node:os";
import { fileURLToPath } from "node:url";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..");

const FAKE = `#!/bin/bash
# Fake duplicacy: log the call, then fail if asked to.
echo "$*" >> "$FAKE_DUPLICACY_CALLS"
if [ "$1" = "$FAKE_DUPLICACY_FAIL" ]; then
  echo "fake $1 failed" >&2
  exit 100
fi
echo "fake $1 ok"
`;

let dir, script, calls;

beforeEach(() => {
  dir = mkdtempSync(join(tmpdir(), "obsidian-sh-"));
  script = join(dir, "obsidian.sh");
  copyFileSync(join(ROOT, "obsidian.sh"), script);
  chmodSync(script, 0o755);
  writeFileSync(join(dir, "duplicacy"), FAKE);
  chmodSync(join(dir, "duplicacy"), 0o755);
  mkdirSync(join(dir, "vault"));
  calls = join(dir, "calls.txt");
});

afterEach(() => rmSync(dir, { recursive: true, force: true }));

function run(args = [], env = {}) {
  const r = Bun.spawnSync(["bash", script, ...args], {
    cwd: dir,
    env: {
      PATH: process.env.PATH,
      HOME: dir,
      DUPLICACY_PATH: join(dir, "duplicacy"),
      TARGET_FOLDER: join(dir, "vault"),
      DUPLICACY_STORAGE: "fake",
      FAKE_DUPLICACY_CALLS: calls,
      ...env,
    },
  });
  return {
    code: r.exitCode,
    out: r.stdout.toString(),
    err: r.stderr.toString(),
    calls: existsSync(calls) ? readFileSync(calls, "utf8").trim().split("\n") : [],
    log: existsSync(join(dir, "logs/obsidian_backup.log")) ? readFileSync(join(dir, "logs/obsidian_backup.log"), "utf8") : "",
    stamped: existsSync(join(dir, "obsidian_last_run.txt")),
  };
}

describe("a passing run", () => {
  test("backs up, prunes, checks, then stamps the cooldown", () => {
    const r = run();
    expect(r.code).toBe(0);
    expect(r.out).toContain("Backup uploaded");
    expect(r.calls.map((c) => c.split(" ")[0])).toEqual(["backup", "prune", "check"]);
    for (const c of r.calls) expect(c).toContain("-storage fake");
    expect(r.calls[2]).toBe("check -storage fake -a");
    expect(r.stamped).toBe(true);
    expect(r.log).toContain("Backup Finished");
  });

  test("passes no -storage flag when DUPLICACY_STORAGE is empty", () => {
    const r = run([], { DUPLICACY_STORAGE: "" });
    expect(r.code).toBe(0);
    for (const c of r.calls) expect(c).not.toContain("-storage");
  });
});

describe("a failing run", () => {
  for (const step of ["backup", "prune", "check"]) {
    test(`a failed ${step} exits non-zero, says so, and does not stamp the cooldown`, () => {
      const r = run([], { FAKE_DUPLICACY_FAIL: step });
      expect(r.code).toBe(100);
      expect(r.out).not.toContain("Backup uploaded");
      expect(r.err).toContain(`Backup failed at step '${step}'`);
      expect(r.log).toContain(`Backup Failed`);
      expect(r.log).toContain(`step: ${step}`);
      expect(r.stamped).toBe(false);
    });
  }

  test("a failed backup stops before prune and check", () => {
    const r = run([], { FAKE_DUPLICACY_FAIL: "backup" });
    expect(r.calls.map((c) => c.split(" ")[0])).toEqual(["backup"]);
  });

  test("a failed check comes after backup and prune", () => {
    const r = run([], { FAKE_DUPLICACY_FAIL: "check" });
    expect(r.calls.map((c) => c.split(" ")[0])).toEqual(["backup", "prune", "check"]);
  });

  test("a missing vault folder fails before any duplicacy call", () => {
    const r = run([], { TARGET_FOLDER: join(dir, "nope") });
    expect(r.code).toBe(1);
    expect(r.calls).toEqual([]);
    expect(r.stamped).toBe(false);
  });
});

describe("the cooldown", () => {
  test("a run inside 24 hours is skipped and calls nothing", () => {
    writeFileSync(join(dir, "obsidian_last_run.txt"), String(Math.floor(Date.now() / 1000) - 3600));
    const r = run();
    expect(r.code).toBe(0);
    expect(r.out).toContain("Backup skipped");
    expect(r.calls).toEqual([]);
  });

  test("--force ignores the cooldown", () => {
    writeFileSync(join(dir, "obsidian_last_run.txt"), String(Math.floor(Date.now() / 1000) - 3600));
    const r = run(["--force"]);
    expect(r.code).toBe(0);
    expect(r.calls.length).toBe(3);
  });

  test("a failed run leaves an old stamp alone, so the next slot retries", () => {
    const old = String(Math.floor(Date.now() / 1000) - 90000);
    writeFileSync(join(dir, "obsidian_last_run.txt"), old);
    const r = run([], { FAKE_DUPLICACY_FAIL: "check" });
    expect(r.code).toBe(100);
    expect(readFileSync(join(dir, "obsidian_last_run.txt"), "utf8")).toBe(old);
  });

  test("the stamp holds the start time, not the end time", () => {
    const before = Math.floor(Date.now() / 1000);
    const r = run();
    const stamp = Number(readFileSync(join(dir, "obsidian_last_run.txt"), "utf8"));
    expect(r.code).toBe(0);
    expect(stamp).toBeGreaterThanOrEqual(before);
    expect(stamp).toBeLessThanOrEqual(Math.floor(Date.now() / 1000));
  });
});

test("obsidian.sh parses", () => {
  expect(Bun.spawnSync(["bash", "-n", join(ROOT, "obsidian.sh")]).exitCode).toBe(0);
});
