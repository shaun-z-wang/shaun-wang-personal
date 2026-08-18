# RUNLOG (fixtures) — unblocking G1-CDV-26 / 32 / 33

Fixture/pre-state-blocked cases, validated against DEPLOYED STAGING (no FPS).
Owner: fixtures agent. Do NOT edit shared cases.tsv / RUNLOG.md — team-lead consolidates.

Endpoint: `https://rpc-shoppers-shoppers-stg.instacart.team`, Pumpkin RPC over HTTP (curl), no auth.
Provisioned fresh order via DevGen curl (`provision.sh`):
- **order_delivery_id = 20812707924501688** (order_id 20812707924519960, user_id 20812705917215268)

---

## G1-CDV-26 (image >20MB -> too_large, skip, NO Sidekiq retry) — FIXTURE FOUND; RPC fired 200; DD confirmation pending MCP

### Fixture (the actual blocker — now cleared)
Real, live, public https image >20MB, reachable from this env:
- **`https://upload.wikimedia.org/wikipedia/commons/7/7e/%22%27Keep_%27em_Flying%27_is_Our_Battle_Cry%21_First_Class_Fighting_Men_Needed.%22_-_DPLA_-_918eabd110170f060acc575a33b27551.jpg`**
  - `HTTP 200`, `content-type: image/jpeg`, `content-length: 40883803` (~39 MB > 20 MB limit). Verified via curl HEAD + range GET.
  - Found via the Wikimedia Commons API (`Category:Large_images`, filtered mime image/* and size>20MB).
- Backup (octet-stream, also >20MB, if Wikimedia egress is blocked from staging): `https://proof.ovh.net/files/100Mb.dat` (HTTP 200, content-length 104857600).
  - Backup works because `ImageDownloadService` checks **size before content-type** (see below), so any >20MB 2xx https body trips `too_large` regardless of content-type.
- Dead ends: `httpbin.org/bytes/N` caps at 100KB (cannot exceed the limit); `speed.hetzner.*` HEAD failed from this env.

### Source behavior confirmed (image_download_service.rb)
`shoppers/shoppers/domains/delivery_domain/app/domain/delivery_domain/services/delivery_verification/image_download_service.rb`
- `MAX_DOWNLOAD_BYTES = 20 * 1024 * 1024`.
- Order of checks inside the SsrfFilter.get block: `response.value` (2xx) -> **Content-Length > MAX -> `failure_reason="too_large"; next`** (line 57-61) -> else stream body, break to `too_large` if bytes exceed MAX (line 63-69) -> only THEN content-type allow-list. So content-type is never reached for an oversized body.
- `too_large` is a **log-and-skip** (sets `failure_reason`, returns nil at line 80-83) — it is NOT one of the re-raising branches (only `Net::HTTPFatalError/RetriableError` and network errors re-raise). So **no Sidekiq retry** for too_large — matches the case expectation.
- Metric on failure (line 129): `ICMetrics.increment("fulfillment.delivery.delivery_verification.image_download.count", kind:@kind, success:"false", error_type:"too_large")`.
  - In Datadog: `custom.fulfillment.delivery.delivery_verification.image_download.count{kind:signature,success:false,error_type:too_large}`.
- `SignaturePersistenceService#persist` downloads then `return if io.nil?` — no re-raise, nothing persisted (no `order_delivery_properties.customer_signature` row). Confirms "skip".

### Run
- FIRE @ 2026-08-05T21:04:53Z. Signature imageUrl = the 40MB Wikimedia JPEG. order_delivery_id 20812707924501688.
- Request: `{"orderDeliveryId":20812707924501688,"source":"VERIFICATION_SOURCE_FULFILLMENT_PROVIDER","dropoffVerification":{"signature":{"imageUrl":"<40MB wikimedia jpeg>"}}}`
- **HTTP 200 `{}`** (enqueued; async job downloads + trips too_large).

### Evidence status
- **RPC accepted (200).** Fixture proven >20MB and live.
- **Datadog/Blazer confirmation: PENDING** — the Datadog and Blazer MCPs were unreachable/timing out during this run (curl to staging worked fine, health 200). Retry query when MCP is responsive:
  - `sum:custom.fulfillment.delivery.delivery_verification.image_download.count{kind:signature,error_type:too_large}.as_count()` over `now-30m` -> expect a fresh `1` (success:false) at ~21:05Z, and NO retry multiplicity (single emission, unlike the 5xx `http_error` x3).
  - Blazer `shoppers_staging`: `order_delivery_properties` for odid 20812707924501688 should have **no customer_signature** row (skip).
- Doc-vs-actual: the exact `error_type` string is **`too_large`** (matches cases.tsv). `kind` tag = `signature`.

**Disposition: fixture UNBLOCKED + RPC fired 200; needs the one Datadog assertion above to flip to full PASS. The prior "no reachable >20MB fixture" blocker is cleared.**

---

## G1-CDV-32 (provider omits a required verification -> still succeeds; missing_required_verification{kind,step} metric) — RE-CLASSIFY as Group 2 (FPS). Not reproducible in Group 1.

### Root cause (5-whys) — the metric lives in FPS, not shoppers
- The `missing_required_verification` metric is emitted **only by the FPS Go wrapper**, not by the shoppers RPC that Group 1 calls directly:
  - `fulfillment/fulfillment_provider_service/internal/fulfillment_relay_service/service/deliveryverification/delivery_verification_service.go:21`
    `missingRequiredVerificationMetric = "fulfillment_provider_service.delivery_verification.missing_required_verification.count"`.
  - `Service.CreateDeliveryVerification` (line 67-73) calls `observeMissingRequiredVerifications(ctx, req)` **before** forwarding to the shoppers client. That method (line 82-129) calls `GetVerificationRequirements`, diffs it against the payload via `missingKinds` (line 149-164: signature / id_verification / pin), and for each missing kind emits `metrics.Incr(missingRequiredVerificationMetric, {"kind":kind, "step":"dropoff"})` (line 106-110). The wrapper never fails the RPC ("Enforcement stays upstream" — package doc line 1-7).
- The **shoppers** `DeliveryVerificationService` (Group 1's target) has **no** such cross-check. I read the write path end to end:
  - `delivery_verification_service.rb#enqueue_create!` only validates order_delivery_id and pickup-or-dropoff presence, then enqueues.
  - `create_delivery_verification_job.rb#dispatch_dropoff` just persists whatever kinds are present in the payload (packages/photo/id/pin/signature). No requirements fetch, no missing-kind metric.
- Therefore, calling the shoppers RPC directly (Group 1 = no FPS) can **never** emit `missing_required_verification`, even with a fully-populated (alcohol/ID-required) order and an omitting payload. The prior blocker ("DevGen orders have empty GetVerificationRequirements") is a real contributor but NOT the root cause — even a correct requirements pre-state would emit nothing on the shoppers path.
- The "still succeeds" half IS true on shoppers (RPC ignores requirements, persists what's given, returns 200 `{}`) — but the observe-only metric/log is an FPS-tier signal.

**Disposition: STILL BLOCKED for Group 1 by design; RE-CLASSIFY as a Group 2 (FPS-in-the-loop) case.** Verify against FPS's own gRPC DeliveryVerificationService, asserting `custom.fulfillment_provider_service.delivery_verification.missing_required_verification.count{kind,step:dropoff}`. Analogous to the sibling's G1-RP-05 finding (behavior is FPS-side, not RPC-side).

### Doc-vs-actual (metric tag shape)
- Metric name: `fulfillment_provider_service.delivery_verification.missing_required_verification.count` (DD: `custom.` prefix).
- Tags: `kind` in {`signature`,`id_verification`,`pin`,`package`}, `step` in {`pickup`,`dropoff`}. Required-verification omissions are always `step:dropoff` (requirements are dropoff-only).

---

## G1-CDV-33 (recorded package absent from payload -> missing-barcodes log + kind=package metric) — RE-CLASSIFY as Group 2 (FPS). Same root cause as 32.

### Root cause — same FPS wrapper, same metric name, kind=package
- Emitted by the **same** FPS wrapper method `observeMissingRequiredVerifications`:
  - It calls `BulkGetPackages` (line 114), then `logMissingPackages` for pickup and dropoff (line 123-128).
  - `logMissingPackages` (line 131-147): `missingScanIdentifiers(recorded, sent)` = scan_identifiers on recorded packages but absent from the payload; if any, logs **"Packages with barcodes missing from CreateDeliveryVerification request"** with `step`, `count`, `missing_scan_identifiers`, and emits `metrics.Incr(missingRequiredVerificationMetric, {"kind":"package", "step":step})` (line 146).
- So CDV-33's "kind=package metric" is the **same metric** as CDV-32, just `kind:package`. The doc shorthand ("missing_required_verification.count{kind,step}" for 32 vs "kind=package metric" for 33) is one metric with different `kind` tags — worth collapsing in the doc.
- The shoppers `create_delivery_verification_job.rb#bulk_update_packages` does the **opposite** direction: it pushes the payload's scans to `PackagesService.BulkUpdatePackages` and `raise response.error` if a *sent* scan doesn't match a recorded bag (not_found). It does **not** compare recorded-but-omitted packages, and emits no missing-package log/metric. So recording packages first (via ReplacePackages, per the sibling vehicle) then omitting one on a direct shoppers CreateDeliveryVerification call would NOT produce the CDV-33 signal — it would just persist the sent packages and skip the check entirely.

**Disposition: STILL BLOCKED for Group 1 by design; RE-CLASSIFY as Group 2 (FPS).** Verify against FPS: record packages, then send a CreateDeliveryVerification (through FPS) that omits a recorded barcode; assert the "Packages with barcodes missing..." log + `missing_required_verification.count{kind:package,step}`.

---

## Summary for team-lead
- **CDV-26**: fixture blocker CLEARED (40MB Wikimedia JPEG, or proof.ovh.net 100MB backup). RPC fired -> 200. One Datadog assertion pending (MCP was down during the run) to flip to full PASS.
- **CDV-32 & CDV-33**: NOT Group-1-reproducible. The `missing_required_verification` metric + missing-barcodes log are emitted by the **FPS Go wrapper** (`deliveryverification/delivery_verification_service.go`), which Group 1 bypasses. Re-classify both as Group 2 (FPS-in-the-loop). Root cause is architectural (emitter lives in FPS), not a provisioning gap — no shoppers-side requirements/recorded-package pre-state can surface these on the direct RPC path.
