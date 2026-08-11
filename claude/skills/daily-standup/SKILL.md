---
name: daily-standup
description: Produce a short bullet-point daily standup by fanning out 4 subagents (PR updates PT-aligned, Slack activity PT-aligned, calendar meetings, AI chat activity). Defaults to the previous workday (Mon → last Fri). Use when the user asks for "standup", "daily standup", "what did I do yesterday", or /daily-standup.
---

# Daily Standup

Produce a concise, bullet-point standup summary for a single day, suitable to paste into #team-relay-devs.

## Step 1: Determine the day

**Default: the previous workday.** If today is Mon–Fri, previous workday = yesterday (Sun/holidays skipped: if yesterday is Sun, use Fri; if Sat, use Fri). If today is Sat/Sun, previous workday = last Fri. Do NOT ask — just pick it.

Only ask the user when they name something ambiguous ("last week"). If they name a specific day ("Monday", "Friday", "2026-07-21", "yesterday"), use that.

**Always compute the weekday — never eyeball it.** Run `date -d <DATE> +%A` to get the day name for the header (and to resolve "yesterday"/"last Fri" correctly). Do NOT guess the day of week from the date.

```bash
date -d <DATE> +%A          # weekday for the header
date -d yesterday +%F       # resolve "yesterday"
```

Compute the PT day window as UTC bounds — during PDT (Mar–Nov), PT is UTC-7:
- `START_UTC` = `<DATE>T07:00:00Z`
- `END_UTC`   = `<DATE+1>T07:00:00Z`

During PST (Nov–Mar), use `08:00:00Z` instead. Check `TZ=America/Los_Angeles date` if unsure which is in effect.

## Step 2: Preflight — all required MCP must be online

Before fanning out, verify the MCP servers this skill depends on are reachable. **Do NOT proceed with a lossy fallback** — a degraded run silently misses DMs and author-scoped messages (this has caused missed coverage before).

Required, no acceptable fallback:
- **Slack** — `mcp__slack__slack_search_public_and_private` (the `fetch-slack.sh` fallback cannot filter by author or read DMs, so it under-reports).

Verify each is loaded (e.g. via `ToolSearch "select:mcp__slack__slack_search_public_and_private"`, or a trivial probe call). If any required MCP is offline, **STOP and tell the user which server is down** rather than running a partial standup. Only proceed once every required MCP is online.

Calendar (`mcp__google-workspace-mcp__get_events`) has a real CLI fallback (`gws calendar`), so a calendar MCP outage does not block the run — but note in the output that the CLI fallback was used.

## Step 3: Gather context (4 parallel subagents)

**Always fan out — never gather any of these sources yourself in the main context.** Spawn all four in one message with `run_in_background: false` so they run concurrently. This keeps the main context clean and lets the four sources search in parallel.

### Agent 1: GitHub PRs (general-purpose, name: `pr-searcher`)

Use `gh` with PT-aligned timestamps — do NOT rely on `updated:YYYY-MM-DD` alone (GitHub interprets bare dates as UTC and misses PRs that merged after 5pm PT).

```bash
# PRs Shaun updated during the PT day
gh pr list --author shaun-z-wang --state all --limit 50 --repo instacart/carrot \
  --search "updated:<START_UTC>..<END_UTC>" \
  --json number,title,state,mergedAt,createdAt,updatedAt,url

# PRs merged during the PT day (cross-repo)
gh search prs --author shaun-z-wang --limit 50 \
  --merged-at <DATE_PT> \
  --json number,title,url,repository,state
# NOTE: gh search's --merged-at is UTC-day; re-filter results locally against
# the PT window using createdAt/updatedAt if edge PRs matter. When in doubt,
# fetch a 2-day UTC window and filter to the PT window in your head.

# PRs newly opened that day
gh search prs --author shaun-z-wang --created <DATE_PT> --limit 50 \
  --json number,title,url,repository,state,createdAt
```

Report each PR as one line: `#NUMBER title (state)`. Group into **Merged**, **Opened**, **Updated (still open)**.

### Agent 2: Slack (general-purpose, name: `slack-searcher`)

Search for **every message Shaun sent** during the PT day — do NOT enumerate specific channels (misses DMs, ad-hoc channels, threads Shaun replied in elsewhere).

Use `mcp__slack__slack_search_public_and_private` with a `from:` + date query. Shaun's Slack user ID is `U099VU0JGLB` (handle `shaun.wang` — note the DOT, not hyphen; `from:@shaun-wang` silently returns 0 results):

```
from:<@U099VU0JGLB> after:<DATE-1> before:<DATE+1>
```

(Slack's `after:`/`before:` are exclusive on both ends and interpret dates in the user's Slack timezone, which is Arizona/MST (UTC-7 year-round) for Shaun — one hour ahead of PT during PST, aligned with PT during PDT. So `after:2026-07-22 before:2026-07-24` returns messages on 2026-07-23. Pull enough pages to cover the full day; default is ~20 results — paginate with the cursor until exhausted.)

Include DMs — `channel_types` defaults to all, so no config needed, but do NOT filter to a specific channel list.

For each hit, note the channel/DM and a 1-line summary. If a thread looks important, follow up with `mcp__slack__slack_read_thread`.

**Capture Shaun's own `#team-relay-devs` standup post verbatim.** His standups are formatted `Yesterday: … / Today: …`. Return the **`Today:` section verbatim** (the plan he set for the target day) as a separate labeled block — the main agent surfaces it so Shaun can compare planned-vs-actual and reuse the text. If he posted no standup that day, say so.

If `mcp__slack__slack_search_public_and_private` is unavailable, do NOT fall back — the Step 2 preflight should already have stopped the run. Never substitute a channel-list fetch: it misses DMs and author-scoped messages.

Results may exceed the tool's token limit and get spilled to a file; paginate with the cursor and parse each page (channel + time + text) until `pagination_info` reports end of results.

Report as SHORT bullets: discussions Shaun participated in, decisions made, action items given/received, PR review nudges. Under 150 words.

### Agent 3: Meetings (general-purpose, name: `calendar-searcher`)

Use `mcp__google-workspace-mcp__get_events` for the PT date. Filter out Focus Time, Lunch, Clockwise holds, all-day personal events, and declined meetings.

Report as SHORT bullets: meeting name + 1-line context. Under 100 words.

### Agent 4: AI chats (subagent_type: `chat-search`, name: `chat-searcher`)

Search Claude Code and Cursor conversations for the PT date only.

Keywords: FORT, relay, FPS, webhook, fulfillment provider, 3P delivery, publix, freshdirect, RCA, incident, delivery verification, kroger, num_of_bags, observability, bag verification, ContextualError.

**Chat is a context source, NOT a source of record for what shipped.** A conversation file active on the target day routinely re-references older PRs/tickets and revisits past work — do NOT report those as if they happened that day. Only report an item if the *conversation activity itself* (the messages, edits, or commands) is timestamped **within** the PT day. For any PR# or ticket ID you surface, treat it as a **candidate** and mark it clearly (e.g. `[candidate — verify]`); the main agent will confirm it against `gh` before it can appear under "Shipped/worked on". Prefer reporting the *nature* of the session ("traced X call graph", "debugged Y") over claiming a PR was landed.

Report as SHORT bullets: projects, debugging sessions, investigations, decisions, and candidate PRs/tickets (flagged). Under 150 words.

## Step 4: Consolidate

**Cross-verify before consolidating.** Any PR# or ticket surfaced *only* by the chat agent (Agent 4) is a candidate, not a fact — confirm each against `gh` and drop it from "Shipped/worked on" unless its authoritative timestamp lands in the PT window:

```bash
gh pr view <NUM> --repo <owner/repo> --json number,title,state,isDraft,author,createdAt,updatedAt,mergedAt
```

Include it as the day's work only if `createdAt`, `updatedAt`, or `mergedAt` falls within `START_UTC..END_UTC` (Step 1). If it's older (created/last-touched on a prior day), the chat session merely *revisited* it — leave it out, or mention it under context only if genuinely relevant. Authoritative dating comes from **GitHub PR timestamps** and **Slack message timestamps**; chat transcripts never override them.

Synthesize into this format — keep it tight, no filler. `<DAY>` is the `date -d <DATE> +%A` result from Step 1, not a guess:

```markdown
## Standup — <DAY> (<DATE>)

**Planned (from your #team-relay-devs post)**
- [The `Today:` section Shaun posted that day, verbatim. Omit this block if he posted no standup.]

**Shipped / worked on**
- [PRs merged, main coding work, decisions landed]

**Decisions / alignment**
- [Cross-team agreements, scoping calls, design choices]

**Meetings**
- [Meeting name — 1-line context if useful]

**Blockers / follow-ups**
- [PRs waiting review, CI failures, open questions]

result: <one-line self-contained headline>
```

### Style rules
- Lead with outcomes (PR merged, decision made), not activities
- Include PR numbers and ticket IDs
- Cross-reference chat and Slack context to enrich a single line — don't repeat the same item twice under different sections
- If Slack standup was already posted, use it as the outline and layer PR/chat details on top
- Skip empty sections (no meetings? drop the header)
