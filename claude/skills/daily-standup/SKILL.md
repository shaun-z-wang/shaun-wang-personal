---
name: daily-standup
description: Produce a short bullet-point daily standup by fanning out 4 subagents (PR updates PT-aligned, Slack activity PT-aligned, calendar meetings, AI chat activity). Defaults to the previous workday (Mon → last Fri). Use when the user asks for "standup", "daily standup", "what did I do yesterday", or /daily-standup.
---

# Daily Standup

Produce a concise, bullet-point standup summary for a single day, suitable to paste into #team-relay-devs.

## Step 1: Determine the day

**Default: the previous workday.** If today is Mon–Fri, previous workday = yesterday (Sun/holidays skipped: if yesterday is Sun, use Fri; if Sat, use Fri). If today is Sat/Sun, previous workday = last Fri. Do NOT ask — just pick it.

Only ask the user when they name something ambiguous ("last week"). If they name a specific day ("Monday", "Friday", "2026-07-21", "yesterday"), use that.

Compute the PT day window as UTC bounds — during PDT (Mar–Nov), PT is UTC-7:
- `START_UTC` = `<DATE>T07:00:00Z`
- `END_UTC`   = `<DATE+1>T07:00:00Z`

During PST (Nov–Mar), use `08:00:00Z` instead. Check `TZ=America/Los_Angeles date` if unsure which is in effect.

## Step 2: Gather context (4 parallel subagents)

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

Fetch from key channels using PT-aligned UTC bounds:

```bash
/home/bento/.claude/plugins/cache/instacart/slack/39ee3bb5a35c/skills/slack-fetch/scripts/fetch-slack.sh <channel> <START_UTC> <END_UTC>
```

Default channels: `team-relay-devs`, `prj-fort-eng`, `prj-fort-crossteam-eng`, `bot-relay`, `prj-relay-freshdirect`, `prj-publix-relay-migration`.

If available, also `mcp__slack__slack_search_public_and_private` for "Shaun" + current project keywords (FORT, relay, publix, kroger, freshdirect, delivery verification, bag verification, observability, RCA).

Report as SHORT bullets: discussions Shaun participated in, decisions made, action items given/received, PR review nudges. Under 150 words.

### Agent 3: Meetings (general-purpose, name: `calendar-searcher`)

Use `mcp__google-workspace-mcp__get_events` for the PT date. Filter out Focus Time, Lunch, Clockwise holds, all-day personal events, and declined meetings.

Report as SHORT bullets: meeting name + 1-line context. Under 100 words.

### Agent 4: AI chats (subagent_type: `chat-search`, name: `chat-searcher`)

Search Claude Code and Cursor conversations for the PT date only.

Keywords: FORT, relay, FPS, webhook, fulfillment provider, 3P delivery, publix, freshdirect, RCA, incident, delivery verification, kroger, num_of_bags, observability, bag verification, ContextualError.

Report as SHORT bullets: projects, PRs, debugging sessions, code changes, decisions. Under 150 words.

## Step 3: Consolidate

Synthesize into this format — keep it tight, no filler:

```markdown
## Standup — <DAY> (<DATE>)

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
