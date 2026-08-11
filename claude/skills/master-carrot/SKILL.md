---
name: master-carrot
description: Update the carrot repo's local master branch to the latest from origin. Use when the user says /master-carrot or asks to "get latest master", "pull latest carrot", or "update carrot master".
---

# Update carrot master to latest

Bring the local `master` branch of the carrot repo (`/home/bento/carrot`) up to date with `origin/master`.

## Steps

1. Fetch and fast-forward master in one shot from the repo directory:

   ```bash
   git -C /home/bento/carrot fetch origin master && \
   git -C /home/bento/carrot checkout master && \
   git -C /home/bento/carrot merge --ff-only origin/master
   ```

2. Report the outcome concisely: whether master was already up to date or how many commits it advanced (e.g. show `git -C /home/bento/carrot log --oneline -1` for the new HEAD).

## Notes

- `git pull` on this repo can hang; prefer the explicit `fetch` + `merge --ff-only` sequence above, which is faster and won't stall.
- If the current branch is not `master` and has uncommitted changes, the `checkout master` step will fail — surface that to the user rather than stashing or discarding anything.
- Use a generous timeout (fetch on this large repo can take a while); do not abort early on a slow fetch.
- `merge --ff-only` will refuse if local master has diverged from origin. If that happens, report it — do not force or reset without asking.
