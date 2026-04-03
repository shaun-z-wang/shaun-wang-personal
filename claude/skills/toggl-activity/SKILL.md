---
name: toggl-activity
description: Analyze Toggl Track activity data from the local macOS SQLite database. Use when the user asks about time tracking, time spent on apps, Slack usage, productivity analysis, daily/weekly time summaries, or mentions Toggl.
---

# Toggl Activity Analysis

## Database

```
~/Library/Group Containers/B227VTMZ94.group.com.toggl.daneel.extensions/production/DatabaseModel.sqlite
```

Access via `sqlite3` with the path quoted or backslash-escaped.

## Timestamps

All timestamps use **Core Data epoch** (seconds since Jan 1, 2001). Convert to human-readable:

```sql
datetime(TIMESTAMP_COL + 978307200, 'unixepoch', 'localtime')
date(TIMESTAMP_COL + 978307200, 'unixepoch', 'localtime')
```

## Primary Table: ZMANAGEDTIMEENTRY

**Use this table for all "how much time did I spend" questions.** This is the source of truth for active tracked time — it matches what the Toggl app displays.

```sql
CREATE TABLE ZMANAGEDTIMEENTRY (
  Z_PK INTEGER PRIMARY KEY,
  ZDURATION_CURRENT FLOAT,      -- active duration in seconds
  ZSTART_CURRENT TIMESTAMP,     -- start time (Core Data epoch)
  ZDESCRIPTION_CURRENT VARCHAR,  -- user-provided label (often empty)
  ZPROJECT INTEGER,             -- FK to ZMANAGEDPROJECT
  ZTASK INTEGER,                -- FK to ZMANAGEDTASK
  ZWORKSPACE INTEGER,           -- FK to ZMANAGEDWORKSPACE
  ...
);
```

### Key queries

**Daily active time:**
```sql
SELECT
  date(ZSTART_CURRENT + 978307200, 'unixepoch', 'localtime') as day,
  printf('%.0f', SUM(ZDURATION_CURRENT) / 60.0) as minutes,
  printf('%.1f', SUM(ZDURATION_CURRENT) / 3600.0) as hours,
  COUNT(*) as entries
FROM ZMANAGEDTIMEENTRY
WHERE date(ZSTART_CURRENT + 978307200, 'unixepoch', 'localtime') = 'YYYY-MM-DD'
GROUP BY day;
```

**Weekly summary:**
```sql
SELECT
  strftime('%Y-W%W', date(ZSTART_CURRENT + 978307200, 'unixepoch', 'localtime')) as week,
  printf('%.1f', SUM(ZDURATION_CURRENT) / 3600.0) as hours,
  COUNT(DISTINCT date(ZSTART_CURRENT + 978307200, 'unixepoch', 'localtime')) as days
FROM ZMANAGEDTIMEENTRY
GROUP BY week
ORDER BY week DESC;
```

**Time entry timeline with gaps (inactive time):**
```sql
WITH entries AS (
  SELECT
    ROW_NUMBER() OVER (ORDER BY ZSTART_CURRENT) as rn,
    datetime(ZSTART_CURRENT + 978307200, 'unixepoch', 'localtime') as start_time,
    datetime(ZSTART_CURRENT + ZDURATION_CURRENT + 978307200, 'unixepoch', 'localtime') as end_time,
    ZSTART_CURRENT as raw_start,
    ZSTART_CURRENT + ZDURATION_CURRENT as raw_end,
    ZDURATION_CURRENT
  FROM ZMANAGEDTIMEENTRY
  WHERE date(ZSTART_CURRENT + 978307200, 'unixepoch', 'localtime') = 'YYYY-MM-DD'
)
SELECT
  e1.start_time, e1.end_time,
  printf('%.0f', e1.ZDURATION_CURRENT / 60.0) as active_min,
  CASE WHEN e2.raw_start IS NOT NULL
    THEN printf('%.1f', (e2.raw_start - e1.raw_end) / 60.0)
    ELSE NULL
  END as gap_min
FROM entries e1
LEFT JOIN entries e2 ON e2.rn = e1.rn + 1;
```

## Secondary Table: ZMANAGEDACTIVITY

Use for **per-app breakdowns** — which apps/websites/channels were used and for how long. This is the auto-tracker data, more granular than time entries.

```sql
CREATE TABLE ZMANAGEDACTIVITY (
  Z_PK INTEGER PRIMARY KEY,
  ZFILENAME VARCHAR,   -- app name (e.g. "Slack", "Google Chrome", "Cursor")
  ZTITLE VARCHAR,      -- window title (includes channel/DM names, page titles, etc.)
  ZSTART TIMESTAMP,
  ZEND TIMESTAMP,
  ZISIDLE INTEGER,     -- always 0 in practice; ignore this field
  ...
);
```

### Key queries

**App breakdown for a day:**
```sql
SELECT
  ZFILENAME as app,
  printf('%.0f', SUM(ZEND - ZSTART) / 60.0) as minutes,
  COUNT(*) as sessions
FROM ZMANAGEDACTIVITY
WHERE date(ZSTART + 978307200, 'unixepoch', 'localtime') = 'YYYY-MM-DD'
GROUP BY ZFILENAME
ORDER BY SUM(ZEND - ZSTART) DESC;
```

**Slack channel/DM breakdown:**
```sql
-- DMs
SELECT
  SUBSTR(ZTITLE, 1, INSTR(ZTITLE, ' (DM)') - 1) as person,
  printf('%.0f', SUM(ZEND - ZSTART) / 60.0) as minutes
FROM ZMANAGEDACTIVITY
WHERE ZFILENAME = 'Slack' AND ZTITLE LIKE '%(DM)%'
  AND date(ZSTART + 978307200, 'unixepoch', 'localtime') = 'YYYY-MM-DD'
GROUP BY person ORDER BY SUM(ZEND - ZSTART) DESC;

-- Channels
SELECT
  SUBSTR(ZTITLE, 1, INSTR(ZTITLE, ' (Channel)') - 1) as channel,
  printf('%.0f', SUM(ZEND - ZSTART) / 60.0) as minutes
FROM ZMANAGEDACTIVITY
WHERE ZFILENAME = 'Slack' AND ZTITLE LIKE '%(Channel)%'
  AND date(ZSTART + 978307200, 'unixepoch', 'localtime') = 'YYYY-MM-DD'
GROUP BY channel ORDER BY SUM(ZEND - ZSTART) DESC;
```

**List all tracked apps:**
```sql
SELECT DISTINCT ZFILENAME FROM ZMANAGEDACTIVITY ORDER BY ZFILENAME;
```

## Important Rules

1. **Active time = SUM of `ZDURATION_CURRENT` from `ZMANAGEDTIMEENTRY`.** This is the only metric that matters for "how long did I work" questions.
2. **Inactive time is NOT stored.** It's the gaps between consecutive time entries (computed, not persisted).
3. **`ZISIDLE` in `ZMANAGEDACTIVITY` is always 0** — ignore it entirely.
4. **Slack window titles** follow the pattern: `{name} (DM) - Instacart - Slack` or `{name} (Channel) - Instacart - Slack`. The "Activity" feed shows as `Activity - Instacart - Slack`.
5. **`ZMANAGEDACTIVITY` totals will differ from `ZMANAGEDTIMEENTRY` totals.** Activity records include personal usage outside work hours. Always use time entries for the "official" number.

## Other Tables

| Table | Purpose |
|-------|---------|
| `ZMANAGEDPROJECT` | Toggl projects |
| `ZMANAGEDTAG` | Tags on time entries |
| `ZMANAGEDCLIENT` | Clients |
| `ZMANAGEDWORKSPACE` | Workspaces |
| `ZMANAGEDAUTOTRACKERRULE` | Rules for auto-creating time entries from app usage |
