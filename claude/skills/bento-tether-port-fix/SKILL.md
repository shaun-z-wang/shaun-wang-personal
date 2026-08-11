---
name: bento-tether-port-fix
description: Fix `bento remote tether` failures caused by a port already bound on the remote dev box. Use when the user pastes a tether error like "remote port forwarding failed for listen port <N>", "ssh connection failure", "Error with tunneling: exit status 255", or "Tether is unable to reach your instance". Frees the stale reverse-forward port on this remote box (/home/bento).
---

# Bento Tether Port Fix

`bento remote tether` opens an SSH reverse forward from the user's laptop to this remote box. When a prior tether session dies without cleaning up, its `sshd` child keeps the reverse-forwarded port bound, so the next tether fails with:

```
Error: remote port forwarding failed for listen port <PORT>
ssh connection failure
09:06:52AM ERR Error with tunneling: exit status 255
```

The fix runs **here on the remote box** (you are already on it): find and kill the stale `sshd: bento` session holding the port. **You cannot use sudo** — but the stale process is bento-owned, so you don't need it.

## Steps

Extract the `<PORT>` from the error (e.g. `1749`, `15246`). Then:

### 1. Confirm the port is bound

```bash
ss -tlnp 2>/dev/null | grep <PORT>
```

- If this returns a `LISTEN` line → continue to step 2.
- If it returns **nothing**, the port is already free on the remote side. The problem is likely a stale **local** ControlMaster on the user's laptop. Tell the user to run locally: `ssh -O exit <bento-host>` (or delete `~/.ssh/control-*` sockets), then rerun `bento remote tether`. Stop here.

### 2. List sshd sessions and identify the current live one

```bash
who; tty; ps -ef | grep sshd | grep -v grep
```

Sessions look like:
- `sshd: bento [priv]` — root-owned parent (don't target directly)
- `sshd: bento@pts/N` — an interactive session on a tty
- `sshd: bento` or `sshd: bento@notty` — **tty-less children; these are the stale reverse-forward holders**

**Never kill the current live interactive session** (match its pts against `who`/`tty`) or its `[priv]` parent — doing so severs this Claude Code process.

### 3. Kill the stale tty-less bento sshd children, oldest first

Kill one at a time and recheck after each — stop as soon as the port frees:

```bash
kill <PID>
sleep 1
ss -tlnp 2>/dev/null | grep <PORT>
```

The culprit is usually the plain `sshd: bento` (no `@notty`, no pts suffix). Killing it often takes its `[priv]` parent down with it — that's expected.

### 4. If sshd candidates are exhausted and the port is still bound

Look for other bento-owned reverse-forward-shaped processes:

```bash
ps -ef | grep bento | grep -v grep   # look for autossh, ngrok, ssh -R, tether
```

Kill the offender and recheck.

### 5. Confirm and report

```bash
ss -tlnp 2>/dev/null | grep <PORT>   # should return nothing
```

Report: which PID(s) you killed and that port `<PORT>` is now free. The user's `bento remote tether` will reconnect on its next retry (it auto-retries).

## Notes

- This has recurred for ports 1749 and 15246 — the port number varies per tether config, so always read it from the error.
- Do NOT edit files, enter a worktree, or commit anything. Pure ops task.
- Safe to run without asking — killing a stale tty-less bento sshd only drops an already-dead tunnel.
