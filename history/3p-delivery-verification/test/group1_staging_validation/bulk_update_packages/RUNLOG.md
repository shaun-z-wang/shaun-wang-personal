# RUNLOG — Group 1 staging validation, PackagesService.BulkUpdatePackages (no FPS)

Dedicated E2E suite for the RPC method `BulkUpdatePackages` against DEPLOYED
STAGING via direct Pumpkin-RPC-over-HTTP curl (Twirp-style). No FPS in the loop.

Dir: `/home/bento/group1_staging_validation/bulk_update_packages/`
Sibling suite (transport/provisioning ground truth): `../replace_packages/`.

---

## Status: DONE — live staging run PASSED. 14/14 original cases PASS; G1-BUP-09 (multiple_bags) run 2026-08-10 = PARTIAL (behavior verified, metric/log not independently observable). See run entry at bottom.

- Endpoint (Pumpkin RPC over HTTP): `https://rpc-shoppers-shoppers-stg.instacart.team`
- order_delivery_id: `20813429596430808` (freshly provisioned for this suite)
- Auth: no auth header required from this sandbox (`AUTH_HEADER=""`).
- Out-of-band bags-table read confirmed via Blazer `shoppers_staging`.
- 2 behavioral findings (both correct-by-design, documented below); nothing to reclassify to Group 2.

---

## Transport (same as ReplacePackages)

Shoppers `PackagesService` is **Pumpkin RPC over HTTP, NOT gRPC**. Client = curl.
`POST <BASE>/rpc/instacart.fulfillment.domains.packing.v1.PackagesService/<Method>`,
`Content-Type: application/json`, proto3-JSON camelCase body.
- int64 as quoted string; enums as string names; Timestamp as RFC3339 (`"...Z"`);
  wrapper types (StringValue/Int64Value) as bare scalars.
- Health `GET <BASE>/monitors/health` -> 200. Direct curl from this sandbox works, no mesh hop.

## Method contract (verified in code + live)

Handler `packing_domain/app/domain/packing_domain/rpc/packages_service_handler.rb:157`
(`bulk_update_packages`); adapter `.../services/data_store_adapters/bag_data_store_adapter.rb:118`.
- `orderDeliveryId` int64 required; zero -> `invalid_argument "order_delivery_id is required"` (handler:158).
- `packages` repeated `UpdatePackageInput` required, non-empty -> empty raises `invalid_argument "packages is required"` (handler:159).
- Every input MUST have `scanIdentifier`; missing OR blank ("") -> `invalid_argument "scan_identifier is required for every package"` (handler:160, `.blank?`).
- Optional per-input: `foundAt` (Timestamp), `foundVia` (ScanMethod), `verifiedAt` (Timestamp), `verifiedVia` (ScanMethod).
- Keyed by `scan_identifier`; unknown identifier -> adapter raises `ActiveRecord::RecordNotFound` (adapter:260-267) -> handler maps to `not_found` (handler:179-180), metric reason:not_found.
- Whole call runs inside a single `Bag.transaction` (adapter:124-142) -> all-or-nothing.
- Partial update: only keys present per input are written (adapter:133-137) -> no clobber of sibling columns.
- `ScanMethod`: SCAN_METHOD_UNKNOWN=0, SCAN_METHOD_SCANNER=1, SCAN_METHOD_FORCE_MARK=2. UNKNOWN(0) is dropped by `enum_name_or_nil` (handler:262) and never written.

## Provisioning recipe (worked)

DevGen MCP `devgen-mcp-v2-staging` `run_script` with
`devgen/provision_bulk_update_order.yaml`:
1. `create_user` -> user_id (REQUIRED first; without it generate_order fails
   "Couldn't find User with 'id'=0").
2. `generate_order` warehouse_ids=[1] (Safeway), service_type "delivery",
   user_id=$user_id, items_found 10. STOP here (no batch plan -> no FPS).
   -> order_id 20813429596435916, **delivery_id (ORDER_DELIVERY_ID) = 20813429596430808**.

Then SEED 4 clean bags (no found/verified) with known scan_identifiers via
ReplacePackages so every BUP case has a stable target:
`./run_case.sh ReplacePackages requests/SEED_replace_packages.json`
-> ids 1102567067..070, scan BUP-0001..BUP-0004, index 1..4, all found/verified NULL.

## How to run

```
source env.sh   # BASE_URL, ORDER_DELIVERY_ID=20813429596430808, AUTH_HEADER=""
./run_case.sh ReplacePackages   requests/SEED_replace_packages.json      # (re)seed
./run_case.sh BulkUpdatePackages requests/BUP-01_pickup_found_only.json  # a case
./run_case.sh BulkGetPackages   requests/VERIFY_BulkGetPackages.json     # read-back
```
Cases are ordered and stateful (see cases.tsv PRE-STATE). Re-run the SEED to reset.

---

## Per-case live log (2026-08-05, ODID 20813429596430808)

Validation group (run against the fresh seed; NONE mutate state):
- G1-BUP-V01 orderDeliveryId "0" -> 400 `invalid_argument "order_delivery_id is required"`. PASS.
- G1-BUP-V02 packages [] -> 400 `invalid_argument "packages is required"`. PASS.
- G1-BUP-V03 input without scanIdentifier -> 400 `"scan_identifier is required for every package"`. PASS.
- G1-BUP-V04 scanIdentifier "" (blank) -> 400 same msg (blank == missing). PASS.
- Post-V01..V04 read-back: all 4 bags still found/verified NULL, updatedAt still seed time -> validation never touches DB. PASS.

Semantics group:
- G1-BUP-01 pickup, 0001 foundAt 12:00 + foundVia SCANNER only -> found set, verified NULL. PASS.
- G1-BUP-02 dropoff, 0002 verifiedAt 13:00 + verifiedVia SCANNER only -> verified set, found NULL. PASS.
- G1-BUP-03 both, 0003 found 12:30 + verified 13:30 (SCANNER) in one input -> all four set. PASS.
- G1-BUP-04 0004 foundVia SCAN_METHOD_FORCE_MARK -> round-trips (DB "force_mark"). PASS.
- G1-BUP-05 partial no-clobber: 0001 (already had found from BUP-01) sent verified ONLY
  -> found 12:00 PRESERVED, verified 13:15 ADDED. PASS.
- G1-BUP-06 0002 (had verified) sent foundAt 12:10 + foundVia SCAN_METHOD_UNKNOWN
  -> found_at set, found_via stays NULL (UNKNOWN dropped), verified preserved. PASS. (Finding 1)

Error / atomicity group:
- G1-BUP-07 scan NOPE-9999 -> 404 `not_found "Bag not found: order_delivery_id=20813429596430808 scan_identifier=NOPE-9999"`; seed unchanged. PASS.
- G1-BUP-08 [0003 verified->18:00 , NOPE-8888] -> 404 not_found on NOPE-8888;
  read-back: 0003 verified STILL 13:30, updatedAt UNCHANGED (23:08:04) -> the valid
  update in the same call was rolled back. Atomicity across the packages array. PASS.

Multi + idempotency group:
- G1-BUP-10 all 4 in one call, foundAt 14:00:0x + SCANNER -> 4 rows updated, each bag's
  verified_* preserved (0004 verified stays null). PASS.
- G1-BUP-11 replay of BUP-10 -> 200, identical data. updatedAt UNCHANGED vs BUP-10. PASS. (Finding 2)

### Out-of-band bags-table read (Blazer `shoppers_staging`) — final state
```
id          idx scan      found_at              found_via  verified_at           verified_via  updated_at
1102567067  1   BUP-0001  2026-08-05 14:00:00Z  scanner    2026-08-05 13:15:00Z  scanner       23:08:49
1102567068  2   BUP-0002  2026-08-05 14:00:01Z  scanner    2026-08-05 13:00:00Z  scanner       23:08:49
1102567069  3   BUP-0003  2026-08-05 14:00:02Z  scanner    2026-08-05 13:30:00Z  scanner       23:08:49
1102567070  4   BUP-0004  2026-08-05 14:00:03Z  scanner    (null)                (null)        23:08:49
```
Matches RPC read-back exactly. found_via/verified_via persist as lowercase strings
("scanner"); the RPC maps to SCAN_METHOD_SCANNER. All updatedAt equal (BUP-10 write;
BUP-11 replay did not bump) — confirms Finding 2 at the DB layer.

---

## Findings

### Finding 1 — SCAN_METHOD_UNKNOWN is silently dropped (correct-by-design)
Sending `foundVia: "SCAN_METHOD_UNKNOWN"` (enum 0) does NOT write found_via; the
`foundAt` in the same input still persists. Root cause: handler `enum_name_or_nil`
returns nil for zero/`*_UNKNOWN` (handler:163-164,262), so the attr key is never added.
Consequence: a package can end up with a non-null `found_at` and a null `found_via`.
Not a bug — matches UpdatePackage's own handling — but callers must send SCANNER or
FORCE_MARK if they want a via recorded. Worth an explicit note in the API contract.

### Finding 2 — Idempotent replay is a true DB no-op (updated_at NOT bumped)
Re-sending an identical BulkUpdatePackages payload returns 200 with identical data and
does NOT bump `updated_at`. Root cause: adapter calls `bag.update!(update_attrs)` only,
and ActiveRecord skips the SQL UPDATE (and the updated_at touch) when no attribute is
dirty. So replay is safe and cheap — not merely value-idempotent but a genuine no-op.
Anyone asserting on `updated_at` to detect "was this bag re-scanned" should know a
same-value re-scan is invisible.

## Group classification
All BulkUpdatePackages behavior is exercisable via direct RPC curl (Group 1). Nothing
needs reclassification to Group 2 / FPS. Handler + adapter validations, partial-update
no-clobber, whole-array atomic rollback, enum round-trip, and idempotency all confirmed
live against deployed staging with out-of-band DB verification.

---

## Run entry — 2026-08-10: G1-BUP-09 `multiple_bags` (PARTIAL)

Executed the previously NOT-RUN multiple_bags case against deployed staging.

**Expected behavior (grounded in code before running):**
- adapter `resolve_bags_by_scan_identifier` (bag_data_store_adapter.rb:270-281): when a
  scan_identifier matches >1 bag, it logs a `warn` (log_id `cba82003d1c8`, message
  "bulk_update_packages: scan_identifier matched multiple bags; updating all matches"),
  increments `packing_domain.bulk_update_packages.fail{reason=multiple_bags}` (adapter:278),
  and **returns ALL matches** (adapter:281) — it does NOT raise (only the empty/`not_found`
  branch raises, adapter:266).
- `bulk_update_packages` (adapter:139) then calls `bag.update!` on **every** returned bag.
- handler `bulk_update_packages` (packages_service_handler.rb:157-184) only rescues
  `ActiveRecord::RecordNotFound`; multiple_bags never raises -> **HTTP 200**, response carries
  all matched+updated bags.
- Net expected: (a) ALL matching rows updated, (b) `.fail{reason=multiple_bags}` metric +
  warn fire, (c) HTTP 200 with the batch applied.

**Provisioning:** DevGen (`devgen-mcp-v2-staging`) was **OAuth-blocked** this session, so a
fresh order could not be generated. Fallback: reused the prior suite's real staging ODID
`20813429596430808`, which Blazer confirmed had **0 bags** at run time (interference-free).
`ReplacePackages` deletes all bags for the ODID before creating, so the reseed left exactly
the two dup bags. Column existence for the verify query confirmed via Blazer
`information_schema.columns` (Portal MCP OAuth-blocked — documented fallback).

**Seed (precondition):** `requests/BUP-09_dup_scan_seed.json` — two packages sharing
`scanIdentifier=BUP-DUP-1` (visual BUP-DUP-A shelf/A1 + BUP-DUP-B freezer/F3).
`ReplacePackages` -> HTTP 200, `totalPackageCount=2`, ids **1105778075** (index 1) +
**1105778076** (index 2). BulkGetPackages + Blazer both confirm **2 distinct rows, same
`bag_scan_identifier=BUP-DUP-1`, all found/verified NULL** -> case IS seedable (ReplacePackages
does not dedupe).

**Run:** `requests/BUP-09_multiple_bags.json` = BulkUpdatePackages {scanIdentifier BUP-DUP-1,
verifiedAt 2026-08-10T15:00:00Z, verifiedVia SCAN_METHOD_SCANNER} at ~22:54:49 UTC.
-> **HTTP 200**. Response returned **BOTH** bags (1105778075 + 1105778076), each
verifiedVia=SCAN_METHOD_SCANNER, verifiedAt=2026-08-10T15:00:00Z, updatedAt bumped to 22:54:49.

**Out-of-band DB (Blazer `shoppers_staging`):**
```
id          idx scan       found_at found_via verified_at           verified_via updated_at
1105778075  1   BUP-DUP-1  (null)   (null)    2026-08-10 15:00:00Z  scanner      22:54:49.426Z
1105778076  2   BUP-DUP-1  (null)   (null)    2026-08-10 15:00:00Z  scanner      22:54:49.419Z
```
Both matching rows updated; found_* untouched (only verified sent). Matches the code exactly.

**Metric/log:** NOT independently observable this session. Datadog
`packing_domain.bulk_update_packages.fail` returned NO data even unfiltered over a 4h window
(and no staging shoppers logs for the ODID appear in this DD org); quickwit/log-nexus, Portal,
and DevGen were all OAuth-blocked. The metric (adapter:278) and warn (adapter:271-277) fire in
the same `matches.size > 1` block that returns all matches (adapter:281); since both rows were
updated — only reachable via that branch — the emitting branch provably executed, but the
emission itself was not directly captured.

**Result: PARTIAL.** Confirmed: BOTH bags updated + HTTP 200, exactly per code, with
out-of-band DB proof. Not confirmed: the `reason=multiple_bags` metric/warn emission (no
observability path available). No fabrication — the metric assertion is honestly left
unverified.
