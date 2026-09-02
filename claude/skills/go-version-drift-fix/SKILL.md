---
name: go-version-drift-fix
description: Fix Go toolchain version drift on a bento remote box, where the host `go` is older than the version the repo's `go.work`/`go.mod` requires — so gopls (Cursor/VSCode Go extension) fails to load the workspace. Use when the user pastes an error like "Error loading workspace: packages.Load error: ... go: go.work requires go >= X.Y.Z (running go A.B.C)", "gopls can't load packages", or reports the Go workspace broken in Cursor after pulling master. No sudo required.
---

# Go Version Drift Fix

The carrot monorepo's root `go.work` pins a required Go version (`go X.Y.Z` + `toolchain goX.Y.Z`). The bento remote box ships Go as a **root-owned upstream tarball at `/usr/local/go`** (symlinked from `/usr/local/bin/go`). When the repo bumps its required version but the box's tarball hasn't been upgraded yet, gopls fails:

```
Error loading workspace: packages.Load error: err: exit status 1: stderr:
go: go.work requires go >= 1.25.6 (running go 1.24.2)
```

## Root cause (why the obvious fixes DON'T work)

gopls creates a **`GoWork` view rooted at the repo-root `go.work`** that spans the *entire* monorepo, and for that view it execs **`go` from PATH** to run `go list`. PATH's `go` is `/usr/local/bin/go` → the old tarball. Therefore:

- **`go.alternateTools` / `go.goroot` in settings.json do NOT fix it** — they only change gopls's `go env`/`go version` *probe*, not the `go list` subprocess for the go.work view.
- **`ic pesto vscode` does NOT fix it** for this case — it writes `.vscode/settings.json` (GOPACKAGESDRIVER + Bazel Go SDK) in the *app subfolder*, but Cursor's workspace root is usually a parent folder, so the Bazel driver never applies to the root go.work view (`EffectiveGOPACKAGESDRIVER` is empty in the gopls log).
- Relying on `GOTOOLCHAIN=auto` to auto-download is unreliable here — gopls's `go list` path emits the hard `running go A.B.C` error instead of switching.

The **only robust fix** is to make **PATH's `go` resolve to the required version**. `~/.local/bin` sits *ahead of* `/usr/local/bin` in the bento extension-host PATH, so a symlink there wins — **no sudo needed**.

## Steps

### 1. Read the required version from `go.work`

```bash
GOWORK="$(git -C "$PWD" rev-parse --show-toplevel 2>/dev/null)/go.work"
[ -f "$GOWORK" ] || GOWORK="$(go env GOWORK 2>/dev/null)"
REQ="$(sed -n 's/^toolchain go//p' "$GOWORK" | head -1)"
[ -z "$REQ" ] && REQ="$(sed -n 's/^go //p' "$GOWORK" | head -1)"
echo "go.work requires: $REQ"
```

### 2. Confirm the drift and where `go` resolves

```bash
command -v go; go version
ls -la /usr/local/bin/go; cat /usr/local/go/VERSION 2>/dev/null
```

If `go version` already matches `$REQ`, the host is fine — the problem is elsewhere (stale gopls; tell the user to reload the window). Otherwise continue.

### 3. Confirm `~/.local/bin` precedes `/usr/local/bin` in the gopls (extension-host) PATH

This is what actually matters — check the PATH gopls runs with, not just this shell:

```bash
PID=$(pgrep -f 'go/bin/gopls' | head -1)
EXTHOST_PATH=$(tr '\0' '\n' < /proc/$PID/environ 2>/dev/null | sed -n 's/^PATH=//p')
# nothing earlier than /usr/local/bin should already contain a `go`:
IFS=:; for d in $EXTHOST_PATH; do [ "$d" = "/usr/local/bin" ] && break; [ -e "$d/go" ] && echo "SHADOW: $d/go"; done; unset IFS
echo "$EXTHOST_PATH" | tr ':' '\n' | grep -nE '/\.local/bin$|/usr/local/bin$'
```

Expect `~/.local/bin` to appear at a **lower line number** than `/usr/local/bin`, and no `SHADOW:` output. (If gopls isn't running, check any `--type=extensionHost` process instead.) If some earlier dir already has a `go`, put the symlink in *that* dir instead in step 5, or point it at the required SDK.

### 4. Install the required Go via the official downloader (no sudo)

```bash
go install golang.org/dl/go${REQ}@latest
"$HOME/go/bin/go${REQ}" download    # unpacks a full SDK to ~/sdk/go${REQ}
"$HOME/sdk/go${REQ}/bin/go" version # sanity: prints go${REQ}
```

### 5. Symlink `go` into `~/.local/bin` (ahead of the old tarball)

```bash
mkdir -p "$HOME/.local/bin"
ln -sfn "$HOME/sdk/go${REQ}/bin/go" "$HOME/.local/bin/go"
```

### 6. Verify under the extension-host PATH

```bash
PATH="$EXTHOST_PATH" command -v go        # -> /home/bento/.local/bin/go
PATH="$EXTHOST_PATH" go version           # -> go${REQ}
# prove go list works against the workspace:
( cd "$(dirname "$GOWORK")" && PATH="$EXTHOST_PATH" go list ./... >/dev/null 2>err.txt; \
  grep -q 'requires go' err.txt && echo "STILL BROKEN" || echo "OK"; rm -f err.txt )
```

Or test a single module: `cd <app-dir> && PATH="$EXTHOST_PATH" go list ./internal/... ` (exit 0, real package paths, no `requires go` error).

### 7. Tell the user to reload

The fix is durable but gopls must relaunch to pick up the new `go`:

> Reload the Cursor window (Command Palette → **Developer: Reload Window**), or run **Go: Restart Language Server**.

Report: required version, that `~/.local/bin/go` now points at `~/sdk/go${REQ}`, and that they must reload.

## Notes

- **Reversible:** `rm ~/.local/bin/go` restores the old behavior. The `~/sdk/go${REQ}` SDK is a stable, user-owned location (not the module cache), so it survives restarts.
- This also makes the **terminal** `go` = `$REQ` (consistent), which is desirable.
- The permanent org-level fix is the bento base image shipping the newer tarball to `/usr/local/go` (needs root). This shim is the right stopgap until then.
- Go on this box is a plain upstream tarball — **not** brew, asdf, gohan, goenv, gvm, apt, snap, or nix. gohan manages Node CLIs, not the Go compiler. Don't look for a version manager to bump.
- Safe to run without asking: it only adds a user-owned symlink and downloads an official Go SDK. It touches no repo files and needs no worktree.
- If `go version` already equals `$REQ` but gopls still errors, it's a stale server — reload/restart is the fix, nothing to install.
