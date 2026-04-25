---
name: ooo
description: Walks Shaun through the full Enterprise Platform OOO checklist — sets up Gmail vacation auto-reply, creates/extends the Google Calendar OOO block, audits open Linear issues and GitHub PRs (authored + review-requested), and flags items that require manual action (Workday, OpsGenie, Slack handoff post). Use when Shaun says /ooo or asks to set up out-of-office, vacation responder, or run the OOO checklist.
---

# Out-of-Office Checklist

Reference: [Enterprise Platform OOO Process (Confluence 6521585842)](https://instacart.atlassian.net/wiki/spaces/Fulfillment/pages/6521585842/Enterprise+Platform+Out+of+Office+OOO+Process)

## Step 1: Gather inputs

Ask the user (or infer from context):

1. **Start date** (first day OOO)
2. **End date** (last day OOO)
3. **Backup contact** — name + email. Default: Rishab Saraf <rishab.saraf@instacart.com> (Shaun's manager).
4. **Audience scope** for auto-reply — everyone / contacts only / **domain only (default)**.

Compute **return date** = end_date + 1 day.

## Step 2: Run audits in parallel

Kick off all of these at once and assemble findings into a checklist table:

### A. Linear — in-progress / awaiting issues

```
mcp__linear__list_issues with assignee="me", limit=50
```

Surface non-completed issues (status != Done/Canceled/Duplicate). Flag any in active "In Progress" — those need a handoff note.

### B. GitHub — authored PRs + review-requested PRs

```bash
gh pr list --author "@me" --state open --json number,title,url,isDraft,reviewDecision
gh search prs --review-requested=@me --state=open --json number,title,url,repository
```

For review-requested: filter out dependabot bumps (`Bump <pkg> from X to Y`) — they auto-handle. Surface the rest as "needs triage before OOO".

### C. Calendar — existing OOO block

```bash
gws calendar events list --params '{"calendarId": "primary", "q": "OOO", "timeMin": "<start - 1 week>T00:00:00-07:00", "timeMax": "<end + 1 week>T00:00:00-07:00", "singleEvents": true}'
```

Look for `eventType: outOfOffice`. Compare its date range to the requested OOO. **Google Calendar OOO end is exclusive** — for OOO through `end_date` (inclusive), the event end must be `return_date T00:00`.

### D. OpsGenie — flag manual check

The MCP token returns 403 Forbidden on Shaun's schedules — do not call `mcp__opsgenie__get_on_call`, just flag this row as "user must verify in UI". Schedule URL pattern: `https://instacart.app.opsgenie.com/settings/schedule/detail/<id>`.

### E. Workday — flag manual check (cannot access)

## Step 3: Present checklist + plan

Show a table with: Workday, on-call (OpsGenie), in-progress work, code reviews, meetings, calendar block, Slack status, email auto-reply.

For each row:
- ✅ done
- ⚠️ needs verification (or mismatch detected)
- ❌ action needed

Then propose what you'll auto-do:
- Set/update Gmail vacation responder
- Create or extend the Calendar OOO event

**Wait for confirmation before any writes.**

## Step 4: Set Gmail vacation responder

Compute epoch ms (must be **JSON strings** — integers fail schema validation):

```bash
echo "$(date -d '<start-date> 00:00:00' +%s)000"
echo "$(date -d '<end-date> 23:59:59' +%s)000"
```

Default body template:

```
Hi,

I am out of the office from <start> through <end> and will respond when I return on <return_date>. For anything urgent, please reach out to <contact_name> (<contact_email>).

Thanks,
Shaun
```

Default subject: `Out of office`

Send:

```bash
gws gmail users settings updateVacation --params '{"userId": "me"}' --json '{
  "enableAutoReply": true,
  "responseSubject": "Out of office",
  "responseBodyPlainText": "<body with \\n for newlines>",
  "restrictToContacts": false,
  "restrictToDomain": true,
  "startTime": "<epoch_ms_string>",
  "endTime": "<epoch_ms_string>"
}'
```

Scope mapping:
- everyone → `restrictToContacts: false`, `restrictToDomain: false`
- contacts only → `restrictToContacts: true`, `restrictToDomain: false`
- domain only → `restrictToContacts: false`, `restrictToDomain: true`

## Step 5: Create / extend the Calendar OOO event

If no `outOfOffice` event exists in the date range, create one:

```bash
gws calendar events insert --params '{"calendarId": "primary"}' --json '{
  "summary": "Shaun OOO",
  "eventType": "outOfOffice",
  "start": {"dateTime": "<start>T00:00:00-07:00", "timeZone": "America/Phoenix"},
  "end":   {"dateTime": "<return_date>T00:00:00-07:00", "timeZone": "America/Phoenix"},
  "outOfOfficeProperties": {
    "autoDeclineMode": "declineAllConflictingInvitations",
    "declineMessage": "Declined because I am out of office"
  },
  "visibility": "public"
}'
```

If one exists with a wrong end, patch it (Slack auto-syncs from this event):

```bash
gws calendar events patch --params '{"calendarId": "primary", "eventId": "<id>"}' --json '{
  "end": {"dateTime": "<return_date>T00:00:00-07:00", "timeZone": "America/Phoenix"}
}'
```

## Step 6: Final reminders to surface

Tell the user explicitly:
- **Workday:** confirm time-off request submitted and approved (system of record).
- **OpsGenie:** verify no on-call shifts during the OOO range; swap if any. Update OpsGenie schedule.
- **Dev channel post:** post a handoff summary in `#team-relay-devs` (or `#team-connect-fulfillment-devs`) before last day, covering on-call swap + in-progress work status.
- **Code reviews:** triage non-dependabot review-requested PRs before EOD last working day.
- **Slack status:** auto-syncs from the Calendar OOO event with `autoDeclineMode` set — no manual action needed if calendar block is correct.

## Disable when back

```bash
gws gmail users settings updateVacation --params '{"userId": "me"}' --json '{"enableAutoReply": false}'
```

## Verify auto-reply

```bash
gws gmail users settings getVacation --params '{"userId": "me"}'
```

## Troubleshooting: 403 insufficient scopes on updateVacation

Required scope: `https://www.googleapis.com/auth/gmail.settings.basic`. If missing, re-auth:

```bash
gws auth login --scopes <comma-separated existing scopes from ~/.config/gws/granted_scopes.json>,https://www.googleapis.com/auth/gmail.settings.basic
rm ~/.config/gws/token_cache.json   # force refresh; new scopes won't take effect otherwise
```

Then retry the updateVacation call.
