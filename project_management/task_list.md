# Complete Task & Project Inventory (2026-03-20)

> **Points**: 1 point = half day of work

## 1. 3P Delivery Project (MVP)

### FPS (Fulfillment Provider Service) — My Tasks
- **Review** — Async Job Usage Patterns (FUL-183552) `2pt`
- **Not started** — FPS project coordination (assign tasks, review, unblock team) `2pt/week`
- **Future** — AI review of FPS-specific code/rules `2pt`

### 3P Delivery MVP Implementation — My Tasks
- **Development** — Finish e2e for inbound webhook: Acknowledge Delivery (FUL-183561) `2pt`
- **Not started** — Reconciliation job `6pt`
- **Not started** — Remaining inbound webhooks (all types) `10pt`
- **Not started** — Look into Orders × Fulfillment cancel integration (Josh Han asking about proposeDeliveryChange/confirmDeliveryChange for OOF cancel) `1pt`
- **Not started** — Cancel Delivery endpoint (FUL-181431) `2pt`
- **Not started** — Get Delivery endpoint (FUL-181430) `4pt`
- **Not started** — Figure out what's missing for order weight, needs to be done before code complete (FUL-182515) `2pt`
- **Apr 27** target for 3P Delivery APIs per DORCH

### Testing
- **Not started** — Review Mark's E2E testing decision (option 3: split admin providers), understand implications for FPS testing `1pt`
- **Scoping** — As a team, decide on e2e test steps (FORT Test Tracker doc) `2pt`

---

## 2. Publix API Migration

- **Review** — Verify rollout dashboard is working, figure out missing validate_order and get_availability metrics `1pt`
- **HIGH PRIORITY / Development** — RCA: port to format, present, address action items (FUL-184648) `6pt`
- **Not started** — Test order invalid fix in dev (after RCA) `3pt`
- **Apr 6 / Rolling out** — Roll out to 10 locations `2pt`
- **Not started** — Roll out to 10% of locations `2pt`

---

## 3. Publix Relay Migration

- **Review** — Sebastian — Review/rework 3PR implementation with feature flag `1pt`
- **Review** — The cancel-research claude mentioned there are Publix orders where service type is nil `2pt`
- **Not started** — Rollout: once location stable 1 week on API migration → add to relay `2pt`
- **Not started** — Rollout and monitor `2pt`

---

## 4. Observability Improvements (cross-project)

- **Not started** — Improved rollout monitoring (design dashboard, review applicability to all relay projects, update dashboards) `5pt`
- **Future** — Add instrumentation wrapper to all Relay APIs `10pt`
- **Future** — Check on relay observability task force to see what's on there
- **Future** — Figure out order impact per endpoint `4pt`
- **Review** — Make empty order_items / won't build order cake product a known error (PR #754596)

---

## 5. RCA Tasks

- **HIGH PRIORITY / Development** — Publix API migration RCA (FUL-184648) `6pt`
- **Not started** — Add monitoring on rising submission failures (FUL-184889) `2pt`
- **Development** — Add monitoring for order submission volume (FUL-184668) `1pt`
- **Development** — Add high-fidelity monitoring to GetIntegrationEnabled API (FUL-184665, was due Mar 23) `1pt`
- **Not started** — DDC alert runbooks `2pt`

---

## 6. AI Project

- **Mar 23–24** — Dedicate 2 full days to team-decided AI work `4pt`
- **Not started** — Publish Tmax window update icon hook plugin `1pt`
- **Future** — Look into Graham's Claude Cowork incident notification plugin `2pt`
- **Future** — Look into Nathan's oncall-bot for auto-investigating alerts `2pt`

---

## Timeline Context

- FPS coding estimated complete ~**April 4**, 3P Delivery coding ~**April 10** (at 1.37x velocity)
- DORCH says 3P Delivery APIs target **Apr 27**
- FORT Gantt shows project slipped **1.5 weeks** due to RCA workload + AI focus days
- Unavailable **2 weeks starting April 25**
- Everyone unavailable **~1 week/month** for oncall rotation
