---
name: oncall-handoff
description: Populate the Relay oncall handoff doc by reading the rotation week's alerts/pages from #bot-relay, grouping by issue, and writing the table + rotation stats. Use when the user says /oncall-handoff or asks to fill in the Relay handoff notes / oncall handoff doc.
---

# Relay Oncall Handoff

Automate filling the per-rotation tab in the [Relay Oncall Handoff Notes](https://docs.google.com/document/d/1Abiln1zoaiiVdcgJyqIaDu0_bPTt4WtRSVb_MAtZKvw) doc.

## Constants

- **Doc ID:** `1Abiln1zoaiiVdcgJyqIaDu0_bPTt4WtRSVb_MAtZKvw`
- **Channel:** `#bot-relay` (ID `C0AJ60SFUDD`)
- **Tab title format:** `YYYY-MM-DD-YYYY-MM-DD` (Tue→Tue rotation)
- **Rotation window:** Tuesday 09:00 PT → following Tuesday 09:00 PT

## Step 1: Identify the rotation tab

1. Call `mcp__google-docs__listTabs` on the doc.
2. Pick the tab whose end date matches today (or the most recent past Tuesday). If ambiguous, ask the user which tab to populate.
3. Capture `tabId` and parse `<startDate>` / `<endDate>` from the tab title.

## Step 2: Pull alerts from #bot-relay

1. Compute Unix timestamps:
   ```bash
   date -u -d '<startDate> 16:00:00' +%s   # 9am PT = 16:00 UTC during DST
   date -u +%s                              # now
   ```
   (PT = UTC-7 during DST; UTC-8 otherwise — sanity-check for the rotation week.)
2. `mcp__slack__slack_read_channel` with `channel_id: C0AJ60SFUDD`, `oldest`/`latest` set, `limit: 500`. Paginate until exhausted.
3. **Bot bodies (Opsgenie/Datadog) read as empty** — that is expected, they are block-kit. Don't waste time trying to extract content from them directly.
4. To get the human context, call `mcp__slack__slack_search_public` with `query: "in:#bot-relay from:@<user>"`, `after: <startDate>`, `sort: timestamp`, `sort_dir: desc`. The user's reply threads contain Blueberry tl;dr summaries plus the user's own diagnosis — these are the source of truth for what each alert was about.

## Step 3: Group alerts by issue

For each cluster (alerts that fire repeatedly for the same root cause count as one group):

- **Slack permalink:** prefer the parent thread the user replied to. Format:
  `https://instacart.slack.com/archives/C0AJ60SFUDD/p<message_ts_no_dot>`
  Use the user's reply permalink when the thread parent is bot-only (since bot threads are easier to navigate by jumping to a human reply).
- **Alert details:** read the Blueberry bot reply in the thread (severity, retailer scope, error class).
- **Linear tickets:** note any `RELAY-NN` IDs surfaced in replies — those go in Next Steps.

## Step 4: Compute rotation stats

- **Pages / Incidents:** count of distinct issue groups (not raw page count).
- **Night Pages:** firings between 22:00–06:00 PT.
- **Weekend Pages:** firings on Sat/Sun PT (convert UTC carefully — a Sunday morning MST page is still Sunday PT).
- **Bugs:** default `0` unless the user surfaces triage-only bugs.

## Step 5: Write back to the doc

Use `mcp__google-docs__replaceDocumentWithMarkdown` with `tabId` and `firstHeadingAsTitle: true`.

Markdown skeleton (preserve every section — Template tab `t.0` is the canonical reference):

```markdown
# Relay Oncall Handoff Notes

[[Relay] Oncall Process](https://instacart.atlassian.net/wiki/spaces/Fulfillment/pages/6413123713/Relay+Oncall+Process)

# Rotation Info

Start Date: <startDate>

End Date: <endDate>

Current Oncaller: <name>

Next Oncaller: <name>

# Rotation Stats

\# Pages / Incidents: <N>

\# Night Pages: <N>    \# Weekend pages: <N>

\# Bugs: <N>

# Pages/Incidents/Bugs

Also create a tab in the alert tagging doc and link it here: [https://docs.google.com/document/d/1HTElkIzQqLShd_5UBdXxyCvjolUYULa1en9I4S1Jjxo/edit?tab=t.m627duip1rb9](https://docs.google.com/document/d/1HTElkIzQqLShd_5UBdXxyCvjolUYULa1en9I4S1Jjxo/edit?tab=t.m627duip1rb9) *(Update this link to point to the tab)*

And then add a row to the [Enterprise Platform Oncall Effectiveness](https://docs.google.com/spreadsheets/d/1y8YAj_jNndS87QStylUf4v8SZGRflPli1v0S2sFrA5g/edit?gid=0#gid=0) sheet where we're tracking the tagging over time.

| Issue Summary | Current Status | Next Steps | Carry Over |
| --- | --- | --- | --- |
| [<title>](<slack-permalink>) — <one-line summary> | Resolved/Mitigated/Ongoing | <action items, RELAY-NN links> | Yes/No |
| ... |

Note:

- To sort a column: Right Click -> "Sort Table"

# Other Bugs & Asks

[Linear](https://linear.app/instacart/team/RELAY/all)

# Action Item Tracking

- [Linear - Relay › Triage](https://linear.app/instacart/team/RELAY/triage) - Items that the new on call will need to pick up
- [Relay › Active issues](https://linear.app/instacart/team/RELAY/active) - All open items - Remind folks to ping people that are waiting for responses from and to update tickets.

# Watch-Outs


# Discussions
```

Notes:
- `\#` escapes are required — those lines are plain text in the source doc, not Heading 1.
- The `replaceDocumentWithMarkdown` write affects only the targeted `tabId`; other tabs are untouched.

## Step 6: Warn about known caveats

After the write succeeds, tell the user:

1. **Person mentions** for Current/Next Oncaller become plain text (markdown can't express `@chips`). If they want chips, re-add them in the doc.
2. **Rich-link chip** to the Enterprise Platform Oncall Effectiveness sheet becomes a regular hyperlink (still works).
3. **Link color may bleed** into trailing non-link text inside table cells — explicitly flag so the user can fix. Workaround: put the link at the end of the cell, or on its own line.
4. **Verification readback may be blocked** by Runlayer security scan on the response (slack URLs trip it). The write itself succeeds regardless — confirm by opening the doc in the browser.
