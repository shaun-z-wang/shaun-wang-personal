# Complete Task & Project Inventory (2026-03-19)

> **Points**: 1 point = half day of work

## 1. 3P Delivery Project (MVP)

### FPS (Fulfillment Provider Service) — My Tasks
- **Review** — Async Job Usage Patterns (FUL-183552) `1pt`
- **Not assigned** — Add autoscaling, tune CPU memory allocation (FUL-185106) `2pt`
- **Not assigned** — Add canary deployment (FUL-185104) `2pt`
- **Not assigned** — Error handling Tier 3 `2pt`
- **Future** — AI review of FPS-specific code/rules `2pt`

### FPS — Others' Tasks
- **Review** — Xiangpeng — FPS Configuration PR #750363 (review requested) `1pt`
- **Development** — Xiangpeng — Design and add integration testing (FUL-185107)
- **Development** — Xiangpeng — Migrate FPS RPCs to generic SubmitBatch/CancelBatch (FUL-185125)
- **Development** — Qinwei — FPS monitoring plan (Relay section)

### 3P Delivery MVP Implementation — My Tasks
- **Development** — Finish e2e for inbound webhook: Acknowledge Delivery (FUL-183561) `2pt`
- **Not started** — Reconciliation job `4pt`
- **Not started** — Remaining inbound webhooks (all types) `6pt`
- **Not started** — Look into Orders × Fulfillment cancel integration (Josh Han asking about proposeDeliveryChange/confirmDeliveryChange for OOF cancel) `2pt`
- **Not started** — Cancel Delivery endpoint (FUL-181431) `4pt`
- **Not started** — Cancel Batch endpoint `3pt`
- **Not started** — Get Delivery endpoint (FUL-181430) `4pt`
- **Not started** — Figure out what's missing for order weight, needs to be done before code complete (FUL-182515) `2pt`
- **Apr 27** target for 3P Delivery APIs per DORCH

### Testing
- **Not started** — Review Mark's E2E testing decision (option 3: split admin providers), understand implications for FPS testing `1pt`
- **Scoping** — As a team, decide on e2e test steps (FORT Test Tracker doc) `2pt`

---

## 2. Publix API Migration

- **Review** — Rollout group tracking PR (#751947) `1pt`
- **Review** — Verify rollout dashboard is working, figure out missing validate_order and get_availability metrics `1pt`
- **HIGH PRIORITY / Development** — RCA: port to format, present, address action items (FUL-184648) `4pt`
- **Not started** — Test order invalid fix in dev (after RCA) `1pt`
- **Mar 21 / Rolling out** — Roll out to 1 location, monitor errors `1pt`
- **Apr 6 / Rolling out** — Roll out to 10 locations `2pt`

---

## 3. Publix Relay Migration

- **Review** — Sebastian — Review/rework 3PR implementation with feature flag `1pt`
- **Review** - The cancel-research claude mentioned there are Publix orders where service type is nil `1pt`
- **Not started** — Rollout: once location stable 1 week on API migration → add to relay `2pt`
- **Not started** — Rollout and monitor `2pt`

---

## 4. Observability Improvements (cross-project)

- **Not started** — Improved rollout monitoring (design dashboard, review applicability to all relay projects, update dashboards) `4pt`
- **Not started** — Add instrumentation wrapper to all Relay APIs `4pt`
- **Not started** — Check on relay observability task force to see what's on there `1pt`
- **Future** — Figure out order impact per endpoint `4pt`

---

## 5. RCA Tasks

- **HIGH PRIORITY / Development** — Publix API migration RCA (FUL-184648) `4pt`
- **Not started** — Add monitoring on rising submission failures (FUL-184889) `2pt`
- **Development** — Add monitoring for order submission volume (FUL-184668) `2pt`
- **Development** — Add high-fidelity monitoring to GetIntegrationEnabled API (FUL-184665, was due Mar 23) `2pt`
- **Not started** — DDC alert runbooks `3pt`

---

## 6. AI Project

- **Mar 21** — Review AI Readiness for Connect Fulfillment [doc](https://docs.google.com/document/d/1eY72GPvFxXGMxCh2Abt4MAnP1nPRxdQVmzdy99Eey_A/edit), check if Relay has any items (due Mar 21 for pillar review) `1pt`
- **Mar 23–24** — Dedicate 2 full days to team-decided AI work `4pt`
- **Not started** — Publish Tmax window update icon hook plugin `2pt`
- **Future** — Look into Graham's Claude Cowork incident notification plugin `2pt`
- **Future** — Look into Nathan's oncall-bot for auto-investigating alerts `2pt`

---

## Point Totals

| Section | Active | Future | Total |
|---|---|---|---|
| 1. FPS — My Tasks | 7 | 2 | 9 |
| 1. FPS — Others' (my review) | 1 | — | 1 |
| 1. 3P Delivery MVP — My Tasks | 27 | — | 27 |
| 1. Testing | 3 | — | 3 |
| 2. Publix API Migration | 10 | — | 10 |
| 3. Publix Relay Migration | 6 | — | 6 |
| 4. Observability | 9 | 4 | 13 |
| 5. RCA Tasks | 13 | — | 13 |
| 6. AI Project | 5 | 4 | 9 |
| **Total** | **81** | **10** | **91** |

> **81 active points = ~40.5 work days = ~8 weeks** (not counting Future items, oncall, or interruptions)

---

## Timeline Context

- FPS coding estimated complete ~**April 4**, 3P Delivery coding ~**April 10** (at 1.37x velocity)
- DORCH says 3P Delivery APIs target **Apr 27**
- FORT Gantt shows project slipped **1.5 weeks** due to RCA workload + AI focus days
- Unavailable **2 weeks starting April 24**
- Everyone unavailable **~1 week/month** for oncall rotation
