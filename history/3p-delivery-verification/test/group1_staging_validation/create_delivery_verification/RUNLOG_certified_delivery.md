# RUNLOG — CreateDeliveryVerification: CertifiedDelivery pin_exchange cases (G1-CDV-08/09/11/22)

Agent-owned file (do NOT edit shared cases.tsv / RUNLOG.md). Validated against **deployed staging**, no FPS.
Last updated: 2026-08-05 ~21:22Z.

## STATUS: 08 PASS, 09 PASS, 22 PASS, 11 STILL-BLOCKED (off-nominal shape unprovisionable).

---

## THE UNBLOCKER — provisioning an order with a pin_exchange CertifiedDelivery (delivery_pin set)

**Recipe (WORKED):** `generate_order` with `customer_handoff_pin: "<4-digit>"`.
The knob is documented on the DevGen `generate_order` command: *"customer_handoff_pin: string; if provided, creates a pin exchange certified delivery with this pin."* Source: `shoppers/shoppers/lib/dev_gen/generate_order.rb:176 create_certified_delivery_with_pin` → builds a `certified_deliveries` row with `delivery_pin=<pin>`, `workflow_state=awaiting_arrival`, `certified_delivery_type=pin_exchange`, and sets `order_delivery.certified_delivery=true`.

DevGen `run_script` YAML (drive via curl fallback — MCP `run_script` timed out this session):
```yaml
commands:
- name: "create_user"
  output: ["user_id"]
- name: "copy_warehouse_location_address"
  output: ["address_id"]
  params:
    user_id: $user_id
- name: "generate_order"
  output: ["order_id", "delivery_ids", "delivery_id"]
  params:
    user_id: $user_id
    items_found: 3
    customer_handoff_pin: "4821"
```
curl: `POST https://devgen-rpc-shoppers-shoppers-stg.instacart.team/rpc/instacart.dev_gen.v1.DevGenService/RunScript` body `{"user_id":0,"script_yaml":"<yaml>"}`.

### Provisioned orders
| tag | order_delivery_id | order_id | user_id | delivery_pin | initial CD state |
|---|---|---|---|---|---|
| A | 20812718378501700 | 20812718378519968 | 20812716467215304 | 4821 | awaiting_arrival |
| B | 20812788019501808 | 20812788019500052 | 20812785666215832 | 7391 | awaiting_arrival |

---

## KEY VERIFICATION UNLOCK — read CD state WITHOUT Blazer

Blazer (`shoppers_staging`) **and** Datadog MCPs were **timing out, then unreachable** this entire session (metadata calls worked; data queries did not). Substitute found:

**Internal read RPC `GetPinExchangeCertifiedDelivery`** returns the authoritative `workflowState` straight from the shoppers DB — a stronger signal than the metric. Callable the same way as the verification RPC (Pumpkin/HTTP, no auth):
```
POST https://rpc-shoppers-shoppers-stg.instacart.team/rpc/instacart.fulfillment.delivery.certified_deliveries.v1.PinExchangeCertifiedDeliveryService/GetPinExchangeCertifiedDelivery
Content-Type: application/json ; ic-client-svc: relay.worker.shoppers.shoppers
{"orderDeliveryId": <ODID>}
```
Response: `{"certifiedDelivery":{"orderDeliveryId","deliveryPin","workflowState":"WORKFLOW_STATE_...","createdAt"}}`.
Handler: `shoppers/shoppers/app/rpc/instacart/fulfillment/delivery/certified_deliveries/v1/pin_exchange_certified_delivery_service_handler.rb`.
(There is also a `CreatePinExchangeCertifiedDelivery` write RPC on the same service — an alternate provisioning path that seeds a pin_exchange CD directly, though I used DevGen so the whole order exists.)

Note: `GetVerificationRequirements` does NOT reflect the transition — its `pin.code` reads `certified_deliveries.delivery_pin` regardless of `workflow_state` (`order_delivery_special_requirements_service.rb:405`). Confirmed pre-state via it (`pin:{required:true,code:"4821"}`) but used the CD read RPC for the state assertion.

---

## Handler logic (why each case behaves as it does)
`PinPersistenceService#persist` (`shoppers/shoppers/domains/delivery_domain/app/domain/delivery_domain/services/delivery_verification/pin_persistence_service.rb`):
- L24 `return unless pin_result&.verified` → **verified=false is an early no-op** (no lookup, no metric). [09]
- L27-29 finder: `where.not(delivery_pin:[nil,""]).find_by(order_delivery_id:)` — selects any CD **with a pin**, no type filter.
- L31-39 nil → `success:false reason:not_found`. [10, already PASS]
- L41-48 type != pin_exchange → **warn but continue**. [11]
- L50-58 already COMPLETED → **skip, no metric**. [22]
- L60-62 transition to COMPLETED via `FulfillmentCertifiedDeliveryService`, `success:true`. [08]

Dispatch note: pin-only requests carry no `proof_of_delivery_photo`, so the photo-step re-raise (shared RUNLOG FINDING #3) never fires — `persist_pin` runs (`create_delivery_verification_job.rb:58`, guarded by `if dropoff.pin`). This is why pin cases work on DevGen orders where photo cases don't.

---

## Per-case results

### G1-CDV-08 (P0) — PASS
- Pre-state (read RPC): order A `WORKFLOW_STATE_AWAITING_ARRIVAL`, deliveryPin 4821.
- Request @ 21:17:24Z: `POST .../DeliveryVerificationService/CreateDeliveryVerification` body `{"orderDeliveryId":20812718378501700,"source":"VERIFICATION_SOURCE_FULFILLMENT_PROVIDER","dropoffVerification":{"pin":{"verified":true}}}` → **HTTP 200 `{}`**.
- Post-state (read RPC, ~90s later): order A `WORKFLOW_STATE_COMPLETED` (createdAt unchanged 21:06:27). **Transition awaiting_arrival → COMPLETED confirmed.**

### G1-CDV-09 (P1) — PASS
- Pre-state: order B `WORKFLOW_STATE_AWAITING_ARRIVAL`, deliveryPin 7391.
- Request @ 21:18:59Z: `dropoffVerification.pin.verified=false` → **HTTP 200 `{}`**.
- Post-state: order B **still `WORKFLOW_STATE_AWAITING_ARRIVAL`** (final read 21:21:47Z). PIN workflow not advanced (early `return unless verified`). No-op confirmed.
- (Bonus: order B remains transitionable — a later verified=true would complete it, proving 09 didn't advance/consume it.)

### G1-CDV-22 (P1) — PASS
- Pre-state: order A `WORKFLOW_STATE_COMPLETED` (from case 08).
- Replay @ 21:18:59Z: `pin.verified=true` on the already-COMPLETED CD → **HTTP 200 `{}`**.
- Post-state: order A **still `WORKFLOW_STATE_COMPLETED`**, createdAt unchanged 21:06:27 (final read 21:21:47Z). Already-COMPLETED skip path (L50-58) confirmed — replay is a no-op.

### G1-CDV-11 (P2) — STILL BLOCKED
Needs a CD with `delivery_pin` set AND `certified_delivery_type != pin_exchange` (only two types exist: `signature`, `pin_exchange` — `constants.rb:19-24`). This off-nominal shape is unreachable via available tooling:
- The **only** DevGen path that sets `delivery_pin` is `generate_order` `customer_handoff_pin`, which **hardcodes type=pin_exchange** (`generate_order.rb:184`).
- `change_certified_delivery` command uses `first_or_create` + state transition only — it sets neither `delivery_pin` nor `certified_delivery_type`.
- `CreatePinExchangeCertifiedDelivery` RPC always writes/coerces to pin_exchange (converts any non-pin_exchange row it finds — handler L18-21).
- No arbitrary-Ruby DevGen command in the registered command set (`RubyScriptRunner` exists but is not a `BaseCommand`, so it's not invokable via a `commands:` script); Blazer is read-only.
Recommendation: cover G1-CDV-11 at the **RSpec tier** (unit test on `PinPersistenceService` with a stubbed signature-type CD that has a pin) — it's a defensive telemetry branch for data shapes that normal flows never produce. Request from doc/domain owner if a staging fixture is truly required: a raw-write seeding path (admin or a new DevGen command that sets type+pin).

---

## ROOT CAUSE — PIN completes the cert from ANY state (refutes "must be awaiting_confirmation")

Cross-agent intel claimed a pin_exchange cert at `awaiting_arrival` won't complete via a PIN CreateDeliveryVerification (pipeline supposedly holds until `awaiting_confirmation`). **This is not true for the PIN path.** 5-whys, code-grounded:

- `FulfillmentCertifiedDeliveryService#transition` (`fulfillment_certified_delivery_service.rb:16-38`) does an **unguarded** `certified_delivery.update!(workflow_state: new_state)` at L18 — no state-machine precondition. It completes from any prior state.
- The `awaiting_confirmation`-family gate only affects a **notification side-effect**: L33 `if new_state == COMPLETED && old_state.in?(SIGNATURE_STATES)` sends the confirmation push. From `awaiting_arrival` (not a SIGNATURE_STATE) no push fires, but the **state column still updates to completed**.
- Empirical proof: order A seeded at `awaiting_arrival` (same recipe as order B, which read back `AWAITING_ARRIVAL`), fired a **pin-only** `{pin:{verified:true}}` → read back `WORKFLOW_STATE_COMPLETED`. Reproduced/stable across 4 reads (21:17–21:25Z).

**Reconciliation of the sibling's "frozen / persisted nothing" observation:** that phrasing matches the shared FINDING #3 / RELAY-919 **photo-step abort**, not a state gate. If their CreateDeliveryVerification bundle included a `proof_of_delivery_photo` (or was a full-dropoff bundle), the photo step raises on DevGen orders (`fetch_address_id` → `OrderHandlingDetails.get` raises; no handling details) and aborts the whole job **before** the pin step runs → nothing persists, cert stays at awaiting_arrival. My **pin-only** requests skip the photo step (`create_delivery_verification_job.rb:56-58` guards each step), so pin executes and completes the cert. The "cert driven through a full flow reached completed" they saw used a non-pin mechanism to move state. → No pin-path pipeline gap; G1-CDV-08 does NOT require an `awaiting_confirmation` pre-drive.

Note: DevGen `change_certified_delivery` (the suggested way to pre-drive state) FAILS under `RunScript` with `undefined method 'driver' for nil` (`change_certified_delivery.rb:42` needs `@context[:_current_user].driver` or a `driver_id` param; RunScript with `user_id:0` has neither). Would need a driver/batch context (the alcohol recipe supplies one). Not needed for the pin path per the above.

### DECISIVE before/after (order B) settling #1 vs #2 vs g2
Clean, directly-observed before/after on order B — which was seeded by the plain recipe (no `change_certified_delivery` ever ran on it; the failed change_certified_delivery attempt was on a separate order):
- BEFORE 21:42:11Z: order B `WORKFLOW_STATE_AWAITING_ARRIVAL`, deliveryPin 7391.
- Fire pin-only `{pin:{verified:true}}` @21:42:20Z → HTTP 200 `{}`.
- AFTER 21:43:03Z: order B `WORKFLOW_STATE_COMPLETED`.
→ **Root cause #1 confirmed**: a direct pin CreateDeliveryVerification completes the cert from `awaiting_arrival`. No `awaiting_confirmation` pre-drive was involved in ANY of my completing calls (08 on A, 08 on B).

### g2's two orders, read via GetPinExchangeCertifiedDelivery (both have a pin)
- g2-run1 `20812561353471676` (cert 5743136): deliveryPin **4242**, `WORKFLOW_STATE_AWAITING_ARRIVAL` (still stuck; FPS CreateDeliveryVerification succeeded but cert never advanced). created 20:40:18.
- g2-run2 `20812822520448620`: deliveryPin **4242**, `WORKFLOW_STATE_COMPLETED`. created 21:23:49.

Both g2 certs are pin_exchange with a non-empty delivery_pin, so the pin-persistence finder (`pin_persistence_service.rb:27-29`, non-empty `delivery_pin`) WOULD match — the "no pin on cert" confound is ruled out. Since my direct pin call completes an identical `awaiting_arrival`+pin cert, g2-run1's non-advance is **not** the shoppers cert state machine. It must be the FPS path failing to make the pin step run, i.e. one of:
1. FPS did not carry `dropoff.pin.verified=true` into the CreateDeliveryVerification it sent (pin absent, or verified=false) → `persist` early-returns at `pin_persistence_service.rb:24`; the sync RPC still returns 200. **Most likely.**
2. FPS's dropoff bundle also carried a `proof_of_delivery_photo` → the photo step raises (RELAY-919, no OrderHandlingDetails on DevGen orders) and aborts the job **before** the pin step; sync RPC still returned 200. (Would show `create_delivery_verification_job.retry_exhausted` in DD.)
Distinguisher for g2: inspect the actual dropoff payload FPS sent for run-1 (was `pin.verified=true` present? was a photo present?), or DD `pin_persistence.count` vs `retry_exhausted.count` around run-1's fire time. If run-2 differed only by having been moved to awaiting_confirmation, that is coincidental to the completion — the shoppers side does not gate on it (proven by order B).

## Surprises / doc-vs-actual
1. **The `customer_handoff_pin` knob is the reusable certified-delivery recipe** the shared RUNLOG marked "no DevGen certified-delivery recipe" for 08/09/11/22. It unblocks 08/09/22.
2. **`GetPinExchangeCertifiedDelivery` internal RPC** is a Blazer-independent way to assert `certified_deliveries.workflow_state` — worth adding to the shared "Verification queries" list, especially since Blazer/Datadog were unavailable.
3. **Blazer + Datadog MCPs were down** for the whole session (data queries timed out then returned connection errors). All evidence here is from the CD read RPC (source of truth). The Datadog `custom....pin_persistence.count{success:true}` for 08 could not be captured live; the state transition itself is confirmed.
4. G1-CDV-09/22 emit **no metric** by design (early return / already-completed skip), so Datadog cannot positively confirm them regardless — the read RPC is the correct verifier.
