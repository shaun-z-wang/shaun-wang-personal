---
name: fort-update
description: Draft a weekly status update for the FORT Gantt sheet. Use when the user says /fort-update or asks to write their FORT weekly update.
---

# FORT Weekly Update

Draft a weekly status update for Shaun Wang's Relay 3P Delivery Support work stream in the FORT Gantt sheet.

## Step 1: Determine Date Range

1. Read the FORT Gantt sheet via Glean `read_document` to find the date of Shaun's last weekly update entry.
   - Sheet URL: `https://docs.google.com/spreadsheets/d/1PEtetTbKOdwyuoEb3KGtuR48UK4dlIvpI_XaoG_6Pl8/edit?gid=0#gid=0`
   - Use MCP server `project-0-bento-glean_default` (or `user-glean_default` if unavailable).
2. Propose the date range to the user: from the day after the last update through today.
3. **Wait for user confirmation** before proceeding. If user provides a different range, use that.

## Step 2: Gather Context (use a team of subagents for parallelism)

Once the date range is confirmed, use `TeamCreate` to create a team (e.g. `fort-update-gather`), then spawn **5 subagents in parallel** using the `Agent` tool with `team_name` set to the team. Each agent gathers from one source and sends results back via `SendMessage`. Wait for all agents to complete before proceeding to Step 3.

### Agent 1: Slack search (general-purpose, name: `slack-searcher`)
Fetch full Slack messages (with embedded links) from both channels using the `slack:slack-fetch` skill script:

```bash
# Fetch both channels for the date range (use absolute timestamps)
/home/bento/.claude/plugins/cache/instacart/slack/39ee3bb5a35c/skills/slack-fetch/scripts/fetch-slack.sh prj-fort-crossteam-eng START_DATETT00:00:00Z END_DATE_PLUS_1T00:00:00Z
/home/bento/.claude/plugins/cache/instacart/slack/39ee3bb5a35c/skills/slack-fetch/scripts/fetch-slack.sh prj-fort-eng START_DATETT00:00:00Z END_DATE_PLUS_1T00:00:00Z
```

Then also search Glean for supplemental context (Glean may find threads not visible in the channel fetch):
- Queries: `"Shaun Wang"` and `"relay fulfillment provider webhook delivery"` in both channels, filtered to the date range.

Return a summary of relevant discussions, decisions, embedded links (docs, PRs, tickets), and any PRs or tickets mentioned.

### Agent 2: GitHub PRs (general-purpose)
Search Glean with `app: "github"`, `from: "Shaun Wang"`, filtered to the date range. This captures PRs authored, reviewed, or commented on. Also run a second query for `"Shaun Wang"` with `app: "github"` to catch PRs where Shaun was mentioned but not the author. Return PR numbers, titles, status (merged/open/reviewed/commented), and brief descriptions.

### Agent 3: Google Docs (general-purpose, name: `docs-searcher`)
Search Glean with `app: "gdrive"`, `from: "Shaun Wang"`, filtered to the date range. This captures docs created, edited, or commented on. Filter to docs relevant to FORT, Relay, FPS, 3P delivery, ERDs, RCAs, or design docs.

For each relevant doc found, fetch full content with embedded links using:
```bash
/home/bento/.claude/plugins/cache/instacart/google-docs/39ee3bb5a35c/skills/fetch-google-doc/scripts/fetch-google-doc.sh <google_docs_url>
```
Fall back to Glean `read_document` if the script fails. Return doc titles, URLs, and a brief summary of what was created or updated.

**Important:** After completing the initial search, stay available. The calendar agent may send you additional doc URLs discovered in meeting descriptions. When you receive those, fetch their content using the same script and report a summary of anything relevant.

### Agent 4: Calendar (general-purpose, name: `calendar-searcher`)
Two-step flow:

**Step 1:** Use Clockwise MCP `search_events` with:
- `timeRangeSearch.includeRanges` covering the date range (local time, no timezone offset)
- `validRsvps: ["Accepted"]`

Filter out Focus Time, Lunch, and other Clockwise-generated holds. Identify relevant meetings (FORT, Relay, FPS, Enterprise Platform, RCA, cross-team syncs). Note interviews and OOO days as they affect bandwidth.

**Step 2:** Use Clockwise MCP `fetch_events` on the relevant meeting IDs to get full event details including descriptions. Extract any doc URLs from the `description` field (Google Docs links, Confluence links, Jira links, etc.).

Send any discovered doc URLs to `docs-searcher` via `SendMessage` so it can read their content. Return a list of relevant meetings grouped by day with what was likely discussed.

### Agent 5: Past AI Conversations (chat-search)
Use `subagent_type: "chat-search"`. Search for conversations about FORT, relay, FPS, webhook porting, fulfillment provider service, 3P delivery within the date range. Return summaries of any relevant work or decisions. The chat-search agent will automatically pre-filter files by date when a date range is provided.

### Linear/Jira tickets (optional — no dedicated agent)
Only if the above agents' results reference ticket IDs that need more context, search Glean directly.

## Step 3: Draft the Update

Read style preferences from `~/.claude/memory/relay/fort-weekly-updates.md`, then draft following these rules:

### Format
```
Updates
- bullet 1
- bullet 2

Next Steps
- bullet 1
- bullet 2
```

### Style Rules
- **Concise** — aim for 6-10 bullets in Updates, 2-4 in Next Steps.
- **No blockquote characters** (`>`) in the output.
- **Risks/Blockers** section only if there's something genuinely blocking.
- **Precise verbs** — "Unblocked X", "Merged Y", "Ported Z" not "Set up X" or "Worked on Y".
- **Don't over-attribute** — only say "Drove alignment on X" if Shaun actually led it. Use "Short discussion on X" or "Participated in X" for lightweight involvement.
- **Skip unplanned work / interviews** unless they significantly impacted FORT bandwidth.
- **Meetings aren't updates** — extract what was decided or aligned on, don't list meetings attended.

### Content Priority
1. PRs merged or in review (with PR numbers)
2. Design decisions driven or signed off on
3. Cross-team alignment achieved
4. Blockers raised or resolved
5. Planning / timeline discussions

## Step 4: Present and Iterate

Present the draft and ask if the user wants to adjust anything before copying it into the sheet.
