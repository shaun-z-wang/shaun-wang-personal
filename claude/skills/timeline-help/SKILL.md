---
name: timeline-help
description: Formatting rules and conventions for updating the Project Plan pages in Notion (task inventory, weekly plan, daily done). Use when the user says /timeline-help or asks to update their project plan, task list, weekly plan, or daily done in Notion.
---

# Project Plan — Notion Formatting Rules

These rules apply when reading or updating the **Project Plan** Notion page and its subpages.

## Notion Page Structure

Parent page: **Project Plan** (ID: `32f1dc66-052d-80e2-bb4a-f54938cab16c`)

Subpages:
- **Task & Project Inventory** (ID: `32f1dc66-052d-810f-b5bf-fc8d9d91ab2d`)
- **Weekly Plan** (ID: `32f1dc66-052d-813b-ba73-e0b9a48e46cb`)
- **Daily Done** (ID: `32f1dc66-052d-81bc-932e-c6f21498461e`)

Always use the Notion MCP tools (`notion-fetch`, `notion-update-page`) to read and update these pages. Use `notion-fetch` to read current content before making updates.

## Task & Project Inventory Formatting

### Task Lifecycle Statuses
Use these statuses in order: **Not started** → **Scoping** → **Design** → **Development** → **Review** → **Testing** → **Rolling out**

Additional statuses:
- **Not assigned** — task exists but no owner yet
- **HIGH PRIORITY / {status}** — prefix for urgent items
- **Future** — nice-to-have, not currently planned
- **{Date} / {status}** — when a specific target date applies. Always use exact dates (e.g. "Mar 21 / Rolling out"), never relative dates like "tomorrow" or "next week"

### Bullet Format
- My tasks: `- [ ] **Status** — Description (TICKET-ID)`
- Others' tasks: `- [ ] **Status** — Name — Description (TICKET-ID)`
- Use todo checkboxes (`- [ ]`) for all tasks. Use `- [x]` when marking a task complete.
- Non-task lines (date markers, notes) use plain bullets (`-`)
- Ticket IDs go at the end in parentheses, not inline
- Keep descriptions concise — one line per task

### Organization
- Group tasks by project/workstream with `## N. Project Name` headers
- Within a project, split into subsections by component or ownership (e.g. "My Tasks" vs "Others' Tasks")
- Include a `## Timeline Context` section at the bottom with key dates, velocity estimates, and availability constraints
- Order tasks by descending status within each section — tasks closest to completion at the top: **Rolling out** → **Testing** → **Review** → **Development** → **Scoping** → **Not started** → **Future**. For prefixed statuses (e.g. "HIGH PRIORITY / Development", "Apr 6 / Rolling out"), sort by the underlying status.

## Daily Done Formatting

- Each day gets a `## YYYY-MM-DD` header
- Group items into three sections:
  - `### Meetings` — meetings attended
  - `### Async Discussion` — Slack threads, PR reviews, doc reviews, email
  - `### Individual Work` — coding, research, tooling, planning
- Use checkboxes: `- [x]` for done, `- [ ]` for in progress
- Include PR numbers, ticket IDs, and Slack links where available
- Most recent day at the top

## Weekly Plan Formatting

- Capacity and strategy notes at the top as bold text (no blockquotes)
- Schedule as a markdown table with columns: Week, project allocations, Total, Coordination
- Summary notes and key risks as plain text below the table (no blockquotes)

## Update Rules

- When using `notion-update-page`, prefer `update_content` with targeted `old_str`/`new_str` replacements over `replace_content` to avoid accidentally removing content
- Always `notion-fetch` the page first to get the exact current content before updating
- When adding a new daily done entry, prepend it above existing entries (most recent at top)
