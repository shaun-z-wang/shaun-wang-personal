---
name: incident-investigate
description: Systematically investigate production issues using Datadog metrics, Wittycart logs, Sentry errors, and codebase exploration. Use when the user says /incident-investigate, shares a Datadog dashboard/alert, asks to dig into production errors, or wants root cause analysis for a spike or failure.
---

# Incident Investigation

Systematically investigate production issues by correlating signals across observability tools and the codebase. Follow these phases in order, but adapt based on what information the user provides upfront.

## Phase 1: Understand the Signal

Extract as much context as possible from the user's initial input (screenshot, link, description, alert).

- **Metric name** — the full Datadog metric path (e.g. `custom.domain.api.method.count`)
- **Filters** — environment, tags, group-by dimensions (retailer_id, service_type, error_class)
- **Time range** — when the issue started, whether it's a spike or sustained
- **Affected entities** — which retailer_ids, user_ids, service_types are failing
- **Magnitude** — failure count, rate vs baseline, trend direction (getting worse?)

If the user shares a screenshot, read it carefully for all these details before making any tool calls.

## Phase 2: Query Metrics for Context

Use Datadog MCP (`user-datadog-via-cookbook`) to quantify the problem.

1. **Failures over time** — query the metric with `success:false` (or equivalent), grouped by relevant dimensions, over a wider time range (7d) to see when the spike started:
   ```
   sum:metric.name{success:false,environment:production} by {retailer_id}.as_count()
   ```

2. **Successes for comparison** — query with `success:true` to see if the overall volume changed or just the failure rate:
   ```
   sum:metric.name{success:true,environment:production} by {retailer_id}.as_count()
   ```

3. **Try grouping by error-related tags** (error_class, error_types) — these may be disabled; fall back to other approaches if you get a 400 error about disabled_tags.

4. **Compare before and after** — use a 7-day window with daily intervals to identify exactly which day failures appeared.

Key question to answer: **Is this a new problem or a worsening of an existing one?**

## Phase 3: Search Logs

Use Wittycart MCP (`user-log-nexus-wittycart`) for detailed log entries.

1. **Find the right service** — use `quickwit_service_names_fuzzy_match` to find the correct service name for the domain.

2. **Calculate Unix timestamps** — use `date -d "YYYY-MM-DD" +%s` in the shell to get correct timestamps for the time range.

3. **Search for errors** — search with the index name (usually the cluster name like `customers`), filtering by service and error status:
   ```
   service:service.name AND relevant_keyword AND status:error
   ```

4. **Broaden if needed** — if no results, try:
   - Removing the service filter (the code may run under a different service name than expected)
   - Searching by error class name (e.g. `RescheduleOrder AND status:error`)
   - Searching without status filter to find info-level logs with context

5. **Extract from log hits** — look for `error.kind`, `error.message`, `error.stack`, `retailer_id`, `user_id`, `tx_class`, and timestamps.

## Phase 4: Check Sentry

Use Sentry MCP (`user-Sentry`) for grouped error issues and stack traces.

1. **Find the org** — call `find_organizations` to get the org slug and region URL.

2. **Aggregate errors first** — use `search_events` with a natural language query for counts grouped by title. This is more reliable than `search_issues` for discovery:
   ```
   "count of errors with title containing <keyword> in the last N days grouped by issue and title and project"
   ```

3. **Get issue details** — for each relevant issue ID, call `get_issue_details` to get:
   - Full stack trace (most relevant frame + full trace)
   - **Caused-by chain** — nested exceptions often reveal the true root cause
   - First seen / last seen dates — critical for correlating with the spike
   - Tags (service, environment, build SHA, transaction)
   - Additional context (Datadog trace links, job args, request details)

4. **Correlate first-seen dates** — if a Sentry issue was first seen at the same time as the metric spike, that's likely the new problem.

## Phase 5: Explore the Codebase

Trace from symptoms to code.

1. **Find the metric emission point** — search for the metric name in the codebase to find where success/failure is tagged.

2. **Trace the call chain** — from the metric emission, work backwards and forwards:
   - What API/job/service calls this code?
   - What downstream services does it call?
   - What error handling exists? What gets caught vs re-raised?

3. **Follow the stack trace** — use Sentry stack traces to identify the exact file and line where the error originates. Read those files.

4. **Check for recent changes** — if you can identify the relevant files, check git history for recent modifications that might correlate with the spike.

5. **Look for related risks** — search for similar patterns in sibling models/services (e.g. if one model has a bug, do related models have the same issue?).

## Phase 6: Correlate and Root-Cause

Bring all signals together:

1. **Timeline** — when exactly did the issue start? Does it correlate with a deploy, a Sentry first-seen date, a feature flag rollout, or a data threshold crossing?

2. **Error chain** — trace the full error cascade (e.g. DB error → integration error → job retry → job exhausted → metric failure).

3. **Scope** — which entities are affected? Is it growing? Are there entities that are succeeding where others fail (partial outage)?

4. **Root cause categories**:
   - **Code bug** — type mismatch, overflow, nil handling, logic error
   - **Infrastructure** — timeouts, capacity, network
   - **Data** — schema mismatch, ID overflow, missing records
   - **Configuration** — feature flag, timeout setting, deployment
   - **External** — partner API, third-party service

## Phase 7: Assess and Recommend

1. **Impact summary** — affected users/retailers, error counts, trend direction, customer-facing effects.

2. **Fix complexity** — is it a one-line fix, a migration, a config change, or a design problem?

3. **Recommendation**:
   - **Quick fix + PR** if: small code change, low risk, well-understood root cause
   - **Raise incident** if: customer-facing impact, getting worse, needs coordination, requires DB migration or multi-service changes
   - **Both** if: you can prepare the fix while also alerting stakeholders

4. **Provide actionable output** — Sentry issue links, relevant code file paths, specific line numbers, and draft fix if applicable.

## Cross-Codebase Search Directories

When searching the Instacart monorepo, include:
- `carrot/customers/instacart`
- `carrot/customers/customers-backend`
- `carrot/enterprise/connect-api`
- `carrot/shoppers`

## Tool Reference

| Tool | MCP Server | Best For |
|------|-----------|----------|
| Datadog Metrics | `user-datadog-via-cookbook` | Timeseries, scalar queries, trend analysis |
| Wittycart Logs | `user-log-nexus-wittycart` | Detailed log entries, error messages, stack traces |
| Sentry | `user-Sentry` | Grouped issues, first-seen dates, full stack traces, caused-by chains |
| Glean | `user-glean_default` | Internal docs, runbooks, past incident RCAs |

Always read MCP tool schemas before calling them. If a tool is not authenticated, prompt the user to authenticate it in Cursor MCP settings.
