---
name: disk-clean
description: Free disk space on Shaun's dev box (/home/bento). Use when the user asks about disk usage, running out of space, "what's taking space", cleaning caches, disk full, du/df, or freeing space in the carrot monorepo / graft worktrees / bazel cache / sorbet cache.
---

# Disk Clean

Recipe for reclaiming disk space on this specific machine: home at `/home/bento`, monorepo at `/home/bento/carrot`, graft worktrees at `/home/bento/grafts/carrot`.

Follow the sections in order. Do the safe cleanups without asking; ask before the interactive ones.

## 1. Baseline snapshot

Record these outputs — they're the "before" benchmark to compare against later.

```bash
df -h /home/bento | head -2
du -sh /home/bento/* /home/bento/.[^.]* 2>/dev/null | sort -h | tail -30
du -sh /* 2>/dev/null | sort -h | tail -20
```

**Gotcha**: `du` output can be long. Read the ENTIRE output, not just the tail-visible portion — it's easy to miss big items like `.cache` (251G seen) or `grafts` (155G seen). If you pipe du to a background file, `Read` the whole file, not the first N lines.

Also expect these NOT-reclaimable large items and skip them:
- `/swap-hibinit` (63G swap file)
- `/home/bento/carrot/.git` (37G, shared object store for all grafts)

## 2. Safe cleanups (do without asking)

### a) `graft sync`

Removes merged worktrees. Just run it and report what it removed.

```bash
graft sync
```

### b) Bazel orphan workspace caches

Under `/home/bento/.cache/bazel/_bazel_bento/` there's one hash dir per workspace root Bazel has ever seen. Bazel does NOT garbage collect these when the workspace is deleted. Each dir contains a `DO_NOT_BUILD_HERE` file naming the absolute workspace path — if that path no longer exists, the dir is orphaned.

Critical gotchas:
1. Skip subdirs named `cache` and `install` — those are the shared bazel install, not per-workspace.
2. Bazel marks output files read-only (u-w bit unset) for hermeticity. `rm -rf` fails "Permission denied" on hundreds of files. Must `chmod -R u+w` first.
3. The first `rm -rf` pass (even with errors) deletes enough top-level content that `DO_NOT_BUILD_HERE` itself vanishes. On a retry, treat "missing DO_NOT_BUILD_HERE" as also being orphaned.
4. In zsh, don't name a loop variable `status` — it's read-only.

```bash
cd /home/bento/.cache/bazel/_bazel_bento && for d in */; do
  hash="${d%/}"
  case "$hash" in cache|install) continue;; esac
  ws=$(cat "$d/DO_NOT_BUILD_HERE" 2>/dev/null)
  if [ -z "$ws" ] || [ ! -d "$ws" ]; then
    echo "deleting orphan: $hash ($ws)"
    chmod -R u+w "$d" 2>/dev/null
    rm -rf "$d"
  fi
done
```

Run the loop a second time to mop up any dirs that errored on the first pass.

### c) Sorbet caches

`sorbet/.cache` (HIDDEN dir — easy to miss when eyeballing) inside each Ruby project grows to tens of GB. Sorbet regenerates on next `srb` run, so deletion is safe.

Known location: `/home/bento/carrot/customers/customers-backend/sorbet/.cache`. Also check active graft worktrees.

```bash
find /home/bento/carrot /home/bento/grafts/carrot -type d -path '*/sorbet/.cache' 2>/dev/null | while read d; do
  echo "deleting: $d"
  rm -rf "$d"
done
```

## 3. Post-snapshot

Re-run and compute delta vs baseline:

```bash
df -h /home/bento | head -2
```

Report as: `Before: XG used / Y% | After: XG used / Y% | Reclaimed: ZG`.

## 4. Interactive recommendations (ask before doing)

Present the top remaining space hogs with size + one-line rationale, then ask which to clean.

- **`/home/bento/grafts/carrot/*`** — individual worktrees. Personal-name ones like `shaun-z-wang`, `shaun`, `shaunwang` can be huge (58G, 13G, 6.8G seen). List sorted by size, ask which to `graft rm <name>`.
  ```bash
  du -sh /home/bento/grafts/carrot/*/ 2>/dev/null | sort -h
  ```
- **`/home/bento/.cache/go-build`** — Go build cache (~9G seen). `go clean -cache`.
- **`/home/bento/.rbenv/versions/`** — old unused Ruby versions (16G total seen). Show `rbenv versions` and ask which to delete. Breaking Ruby is disruptive — always confirm.
- **`/home/bento/.cache/yarn`** — Yarn v1 cache (~1.6G seen). `yarn cache clean` or `rm -rf`.
- **`/home/bento/carrot/customers/customers-backend/log`** and `.../tmp` — Rails logs/tmp (700-800M seen). Usually safe to truncate.

## Do NOT touch

- `/home/bento/carrot/.git` — 37G shared object store for all grafts.
- `/swap-hibinit` — 63G swap file.
- Any ACTIVE bazel workspace cache (workspace dir still exists).
- Anything under `/home/bento/.rbenv/versions/` without explicit confirmation.
