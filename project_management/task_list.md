# Complete Task & Project Inventory (2026-03-19)

## 1. 3P Delivery Project (MVP)

### FPS (Fulfillment Provider Service) — My Tasks
- **Review** — Async Job Usage Patterns (FUL-183552)
- **Not assigned** — Add autoscaling, tune CPU memory allocation (FUL-185106)
- **Not assigned** — Add canary deployment (FUL-185104)
- **Not assigned** — Error handling Tier 3
- **Future** — AI review of FPS-specific code/rules

### FPS — Others' Tasks
- **Review** — Xiangpeng — FPS Configuration PR #750363 (review requested)
- **Development** — Xiangpeng — Design and add integration testing (FUL-185107)
- **Development** — Xiangpeng — Migrate FPS RPCs to generic SubmitBatch/CancelBatch (FUL-185125)
- **Development** — Qinwei — FPS monitoring plan (Relay section)

### 3P Delivery MVP Implementation — My Tasks
- **Development** — Finish e2e for inbound webhook: Acknowledge Delivery (FUL-183561)
- **Not started** — Reconciliation job
- **Not started** — Remaining inbound webhooks (all types)
- **Not started** — Look into Orders × Fulfillment cancel integration (Josh Han asking about proposeDeliveryChange/confirmDeliveryChange for OOF cancel)
- **Not started** — Cancel Delivery endpoint (FUL-181431)
- **Not started** — Cancel Batch endpoint
- **Not started** — Get Delivery endpoint (FUL-181430)
- **Not started** — Figure out what's missing for order weight, needs to be done before code complete (FUL-182515)
- **Apr 27** target for 3P Delivery APIs per DORCH

### Testing
- **Not started** — Review Mark's E2E testing decision (option 3: split admin providers), understand implications for FPS testing
- **Scoping** — As a team, decide on e2e test steps (FORT Test Tracker doc)

---

## 2. Publix API Migration

- **Review** — Rollout group tracking PR (#751947)
- **Review** — Verify rollout dashboard is working, figure out missing validate_order and get_availability metrics
- **HIGH PRIORITY / Development** — RCA: port to format, present, address action items (FUL-184648)
- **Not started** — Test order invalid fix in dev (after RCA)
- **Tomorrow / Rolling out** — Roll out to 1 location, monitor errors
- **April 6 / Rolling out** — Roll out to 10 locations

---

## 3. Publix Relay Migration

- **Review** — Sebastian — Review/rework 3PR implementation with feature flag
- **Not started** — Rollout: once location stable 1 week on API migration → add to relay
- **Not started** — Rollout and monitor

---

## 4. Observability Improvements (cross-project)

- **Not started** — Improved rollout monitoring (design dashboard, review applicability to all relay projects, update dashboards)
- **Not started** — Add instrumentation wrapper to all Relay APIs
- **Not started** — Check on relay observability task force to see what's on there
- **Future** — Figure out order impact per endpoint

---

## 5. RCA Tasks

- **HIGH PRIORITY / Development** — Publix API migration RCA (FUL-184648)
- **Not started** — Add monitoring on rising submission failures (FUL-184889)
- **Development** — Add monitoring for order submission volume (FUL-184668)
- **Development** — Add high-fidelity monitoring to GetIntegrationEnabled API (FUL-184665, was due Mar 23)
- **Not started** — DDC alert runbooks

---

## 6. AI Project

- **Tomorrow** — Review AI Readiness for Connect Fulfillment [doc](https://docs.google.com/document/d/1eY72GPvFxXGMxCh2Abt4MAnP1nPRxdQVmzdy99Eey_A/edit), check if Relay has any items (due Friday for pillar review)
- **Next Mon & Tue** — Dedicate 2 full days to team-decided AI work
- **Not started** — Publish Tmax window update icon hook plugin
- **Future** — Look into Graham's Claude Cowork incident notification plugin
- **Future** — Look into Nathan's oncall-bot for auto-investigating alerts

---

## Timeline Context

- FPS coding estimated complete ~**April 4**, 3P Delivery coding ~**April 10** (at 1.37x velocity)
- DORCH says 3P Delivery APIs target **Apr 27**
- FORT Gantt shows project slipped **1.5 weeks** due to RCA workload + AI focus days
- Unavailable **2 weeks starting April 24**
- Everyone unavailable **~1 week/month** for oncall rotation
