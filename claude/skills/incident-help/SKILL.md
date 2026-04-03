---
name: incident-help
description: Guides the user through starting, managing, and resolving incidents at Instacart. Use when the user says /incident-help or asks about incidents, on-call, pages, RCAs, incident bot, or incident response.
---

# Incident Help

Help the user start, manage, and resolve incidents using Instacart's incident response process and tooling.

## Principles

- **Blameless** — focus on systems/processes, not individuals.
- **Fearless** — don't hesitate to declare an incident or ask for help.
- **Unambiguous/Inclusive** — include charts/graphs, avoid unexplained acronyms.
- **Open Minded** — avoid jumping to conclusions.

## Incident Bot Commands (Slack)

| Command | What it does |
|---------|-------------|
| `/incident declare [name]` | Declare and announce an incident in `#incident` |
| `/incident status` | View current status of the incident |
| `/incident page [team]` | Page a team via OpsGenie |
| `/incident mitigate` | Mark incident as mitigated |
| `/incident resolve` | Mark incident as resolved (opens recap modal) |
| `/incident unresolve` | Reopen a resolved incident (also un-mitigates) |
| `/incident unmitigate` | Reopen a mitigated incident |
| `/incident make-private` | Convert incident channel to private |
| `/incident metric [name]` | Share a metric in the incident channel |
| `/incident create-rca` | Manually create an RCA |
| `/incident list` | List all active incidents |
| `/incident help` | View all available commands |
| `/test-incident declare [name]` | Create a test incident in `#bot-development2` (no real impact) |

To declare a private incident from the start, use the `--private` flag.

## Workflow: Declaring an Incident

1. **Declare**: `/incident declare [descriptive name]` in any Slack channel.
2. **Join the channel**: Incident Bot creates a dedicated Slack channel — join it.
3. **Describe impact**: Post what's happening, who's affected, and current severity.
4. **Page relevant teams**: `/incident page [team]` to bring in help via OpsGenie.
5. **Focus on mitigation first** — stop the bleeding before root-causing.
6. **Mitigate**: `/incident mitigate` once initial impact is addressed.
7. **Resolve**: `/incident resolve` once customer experience is restored. Fill out the recap modal.

## Severity Levels

| Level | Meaning |
|-------|---------|
| SEV0 | Critical — widespread customer impact, all-hands response |
| SEV1 | Major — significant customer impact |
| SEV2 | Moderate — limited customer impact |
| SEV3 | Minor — minimal customer impact |
| SEV4 | Informational |

SEV0/SEV1 incidents **require** an RCA. SEV2+ RCAs are recommended if likely to reoccur.

## Handling a Page (5/5/5 Rule)

1. **Acknowledge** within 5 minutes of the page firing.
2. **Start mitigation** within 5 minutes of acknowledging.
3. **Complete mitigation** within 5 minutes of starting.

If unsure how to handle: consult the team runbook, then escalate if needed.

## RCA (Root Cause Analysis)

- Auto-created for SEV0/SEV1; manual via `/incident create-rca`.
- **Draft within 10 business days**, review with stakeholders within 45 business days.
- Sections: Summary, Impact, Timeline, Five Whys / Root Cause, Action Items, Key Takeaways.
- Write for a wide audience — don't assume shared domain knowledge.

## Key Observability Tools

| Tool | What it's for | Link |
|------|--------------|------|
| Datadog | Logs, metrics, traces, dashboards, monitors | `go/datadog` |
| Sentry | Application errors and exceptions | `go/sentry` |
| AWS CloudWatch | Infrastructure logs and metrics | `go/aws` |
| WittyCar | Logs | `go/wittycart` |
| ISC | Build, deploy, rollback services | Instacart Software Center |
| OpsGenie | Paging and alerting | Download app, add vCard |

## Key Slack Channels & Contacts

| Channel / Contact | Purpose |
|-------------------|---------|
| `#incident` | Where incidents are announced |
| `#infra-cloud-foundations` | Infra questions and feedback |
| `#ask-incident-management` | Incident process questions |
| `#bot-development2` | Test incidents land here |
| `@incident-response-team` | Slack handle for IRT |
| `incidentresponse@instacart.com` | Email for IRT |
| OpsGenie: `IC-Incident-Response-Team` | Page the IRT |

## Useful Links

- Incidents Portal: `https://incidents.instacart.tools/incidents`
- Incident Trends: `https://incidents.instacart.tools/charts`
- RCAs: `https://incidents.instacart.tools/rcas`
- OpsGenie setup: `https://instacart.atlassian.net/wiki/spaces/ENG/pages/2115928282/Installing+OpsGenie+as+a+User`

## Incident Response Team (IRT) — Mass Operations

The IRT can process mass operations requests via Jira form:
- Mass Cancellation
- Mass Refund
- Mass Reschedule
- Mass Communication & Appease
- Shopper Messaging (incidents or extreme events)

## Tips

- **Mitigation over root cause** during an active incident. Root-cause fully after impact is resolved.
- When sharing metrics, post a **screenshot + link** (not just a link — others may not have Datadog access).
- Private incidents: channel name is still visible even if the channel is private — keep the name non-descriptive.
- Default to public incidents; only go private for security, legal, or compliance reasons.
