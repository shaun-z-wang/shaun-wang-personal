# Weekly Plan (2026-03-20)

> **Capacity**: 10pt/week for tasks (1pt = half day) | Coordination tracked separately
> **Strategy**: Frontload all RCA tasks, then prioritize dev work (webhooks, Cancel Delivery, Get Delivery). Oncall weeks = 0pt.

| Week | 3P Delivery / FPS | Publix API | Publix Relay | RCA | Observability | AI | Total | Coordination |
|---|---|---|---|---|---|---|---|---|
| **Mar 23–27** | — | — | — | Publix RCA 4pt, submission failures 2pt | — | AI days 4pt | 10pt | FPS 1pt |
| **Mar 30 – Apr 3** | AcknowledgeDelivery 2pt | Dashboard 1pt, test order fix 3pt | — | Publix RCA 2pt, order volume 1pt, GetIntEnabled 1pt | — | — | 10pt | FPS 1pt |
| **Apr 6–10** | Webhooks 8pt | Rollout 10 locs 2pt | — | — | — | — | 10pt | FPS 1pt |
| **Apr 13–17 (oncall)** | — | — | — | — | — | — | 0pt | — |
| **Apr 20–24** | Webhooks 2pt, reconciliation 6pt, order weight 2pt | — | — | — | — | — | 10pt | FPS 1pt |
| *Apr 24 – May 8* | *— leave —* | *—* | *—* | *—* | *—* | *—* | *0pt* | *—* |
| **May 11–15** | Cancel Delivery 2pt, Get Delivery 4pt, Async Job 2pt | Rollout 10% 2pt | — | — | — | — | 10pt | FPS 1pt |
| **May 18–22** | E2e test steps 2pt, testing review 1pt, cancel integration 1pt | — | Sebastian review 1pt, cancel-research 2pt, rollout 2pt | — | — | — | 9pt | FPS 1pt |
| **May 25–29** | — | — | Monitor 2pt | DDC runbooks 2pt | Rollout monitoring 5pt | — | 9pt | FPS 1pt |
| **Jun 1–5** | — | — | — | — | — | Tmax 1pt | 1pt | FPS 1pt |

## Running Totals by Week

| Week | 3P/FPS | Publix API | Relay | RCA | Obs | AI | Task Total | Coord Total |
|---|---|---|---|---|---|---|---|---|
| Mar 23 | 0 | 2 | 0 | 6 | 0 | 5 | 13 | 1 |
| Mar 30 | 2 | 6 | 0 | 10 | 0 | 5 | 23 | 2 |
| Apr 6 | 10 | 8 | 0 | 10 | 0 | 5 | 33 | 3 |
| Apr 13 | 10 | 8 | 0 | 10 | 0 | 5 | 33 | 3 |
| Apr 20 | 20 | 8 | 0 | 10 | 0 | 5 | 43 | 4 |
| *Leave* | — | — | — | — | — | — | — | — |
| May 11 | 28 | 10 | 0 | 10 | 0 | 5 | 53 | 5 |
| May 18 | 32 | 10 | 5 | 10 | 0 | 5 | 62 | 6 |
| May 25 | 32 | 10 | 7 | 12 | 5 | 5 | 71 | 7 |
| Jun 1 | 32 | 10 | 7 | 12 | 5 | 6 | 72 | 8 |

> **All RCA tasks (12pt) done by end of Apr 6** — frontloaded before project work
>
> **Dev work prioritized**: Webhooks → Cancel Delivery → Get Delivery before leave. Reconciliation, debt, and docs pushed after leave.
>
> **Oncall weeks = 0pt** — fully reserved for oncall duties
>
> **All active tasks (72pt) completed by early Jun** + 8pt coordination overhead
>
> Key risks:
> - 3P Delivery APIs target Apr 27 but only ~20pt of 3P work done before leave — **will miss deadline by ~3 weeks**
> - Oncall week assumed Apr 13 — adjust if different
> - No buffer for unplanned work or interruptions
