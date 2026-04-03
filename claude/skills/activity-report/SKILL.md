---
name: activity-report
description: Research what you worked on across Slack, GitHub, Jira, Google Docs, and Calendar using parallel agent teams. Use when the user says /activity-report or asks "what did I do", "what have I been working on", "summarize my activity", or wants to gather work context for a date range.
---

# Activity Report

Research Shaun Wang's work activity across all sources using a parallel agent team, then produce a consolidated summary.

## Step 1: Determine Date Range

If the user specifies a date range, use it. Otherwise:
1. Ask: "What date range? (e.g. 'last week', 'Mar 10-14', 'past 3 days')"
2. Convert to concrete start/end dates based on today's date.

## Step 2: Gather Context (parallel agent team)

Use `TeamCreate` to create a team (e.g. `activity-gather`), then spawn **7 agents in parallel** using the `Agent` tool with `team_name` and `run_in_background: true`. Wait for all to complete before Step 3.

### Agent 1: Slack (general-purpose, name: `slack-searcher`)

Fetch Slack messages from key channels using:
```bash
/home/bento/.claude/plugins/cache/instacart/slack/39ee3bb5a35c/skills/slack-fetch/scripts/fetch-slack.sh <channel> <start>T00:00:00Z <end_plus_1>T00:00:00Z
```

Channels to fetch: `prj-fort-eng`, `prj-fort-crossteam-eng`, and any others relevant to current projects.

Also search with `mcp__slack__slack_search_public_and_private` for:
- "Shaun" in project-related channels
- Project keywords: "3P delivery", "fulfillment provider", "publix", "relay", "RCA"

Report: discussions participated in, decisions made, action items given/received, links shared.

### Agent 2: GitHub (general-purpose, name: `github-searcher`)

Run these gh commands:
- `gh pr list --author shaun-z-wang --state all --limit 50 --repo instacart/carrot --search "created:START..END"` (PRs created)
- `gh pr list --reviewer shaun-z-wang --state all --limit 50 --repo instacart/carrot --search "created:START..END"` (PRs reviewed)

Also search Glean with `app: "github"`, `from: "Shaun Wang"`, filtered to the date range.

Report: PRs authored (merged/open/draft), PRs reviewed, commits, and brief descriptions.

### Agent 3: Google Docs (general-purpose, name: `docs-searcher`)

Search Glean with `app: "gdrive"`, `from: "Shaun Wang"`, filtered to the date range.

For relevant docs found, fetch content using:
```bash
/home/bento/.claude/plugins/cache/instacart/google-docs/39ee3bb5a35c/skills/fetch-google-doc/scripts/fetch-google-doc.sh <google_docs_url>
```

Fall back to Glean `read_document` if the script fails. Stay available for doc URLs sent by the calendar agent.

Report: docs created/edited, what was written or updated.

### Agent 4: Jira (general-purpose, name: `jira-searcher`)

Use `mcp__atlassian__searchJiraIssuesUsingJql` with:
- `assignee = currentUser() AND updated >= "START_DATE" ORDER BY updated DESC` (tickets worked on)
- `assignee = currentUser() AND status NOT IN (Done, Closed, Resolved) ORDER BY priority DESC` (still open)
- `assignee = currentUser() AND status changed during ("START_DATE", "END_DATE") ORDER BY updated DESC` (status changes)

Use `maxResults: 50` and `fields: ["summary", "status", "issuetype", "priority", "updated"]`.

Also search Glean with `app: "jira"`, `from: "Shaun Wang"` as fallback.

Report: tickets updated, status changes, new tickets created, open tickets.

### Agent 5: Calendar (general-purpose, name: `calendar-searcher`)

Use Clockwise MCP `search_events` with:
- `timeRangeSearch.includeRanges` covering the date range
- `validRsvps: ["Accepted"]`

Filter out Focus Time, Lunch, and Clockwise holds. Use `fetch_events` on relevant meeting IDs for descriptions.

Send any doc URLs found in descriptions to `docs-searcher` via `SendMessage`.

Report: relevant meetings grouped by day, what was discussed, any doc/ticket links found.

### Agent 6: Past Conversations (subagent_type: `chat-search`, name: `conversation-searcher`)

Use `subagent_type: "chat-search"` (NOT `general-purpose`). Search for conversations about current projects and work topics within the date range. Keywords to search:
- Project names: "FORT", "relay", "FPS", "webhook", "fulfillment provider", "3P delivery"
- "publix", "migration", "rollout"
- "RCA", "incident", "monitoring"
- Any other project-specific keywords relevant to current work

The chat-search agent will automatically pre-filter conversation files by date. Report summaries of relevant work, decisions, code written, and debugging sessions.

### Agent 7: Time Tracking (subagent_type: `toggl-activity`, name: `toggl-searcher`)

Use `subagent_type: "toggl-activity"` (NOT `general-purpose`). Query for the date range and report:
- Total hours per day
- Top apps by time spent
- Top window titles per app (e.g. which repos in Cursor, which pages in Chrome, which files in VS Code) — use the `ZTITLE` column from `ZMANAGEDACTIVITY`
- Top Slack channels/DMs
- Notable patterns (heavy meeting days, deep focus days, low-activity days)

## Step 3: Consolidate and Present

After all agents complete, synthesize into a structured summary:

```
# Activity Report: [START_DATE] - [END_DATE]

## Key Accomplishments
- [Most impactful work items, PRs merged, decisions made]

## Work by Project
### [Project Name]
- [Specific items worked on]

## Meetings & Collaboration
- [Key meetings, cross-team alignment, reviews]

## Open Items / Carry-forward
- [Things still in progress, action items pending]
```

### Style Rules
- Lead with outcomes, not activities ("Merged PR #123 for webhook endpoint" not "Worked on webhooks")
- Include PR numbers, ticket IDs, and doc links where available
- Group by project/workstream, not by source
- Flag anything that looks blocked or overdue
