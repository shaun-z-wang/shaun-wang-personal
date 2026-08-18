# RUNLOG — Group 1 staging validation, PackagesService.ReplacePackages (no FPS)

Durable, incremental log of what was tried and what worked. Source of truth for
the final report. No secrets are recorded here (tokens/certs described, never pasted).

Dir: `/home/bento/group1_staging_validation/replace_packages/`

---

## Status: DONE — live staging run PASSED, no FPS in the loop

- Endpoint (Pumpkin RPC over HTTP): `https://rpc-shoppers-shoppers-stg.instacart.team`
- order_delivery_id: `20812396763494404`
- Auth: no auth header required from this sandbox.
- All §1.3 RPC-testable cases PASS. One doc misclassification found (G1-RP-05).

---

## Transport (resolved)

The shoppers `PackagesService` is **Pumpkin RPC over HTTP (Twirp-style), NOT gRPC**.
- Client = curl. `POST <BASE_URL>/rpc/<pkg.Service>/<Method>`, `Content-Type: application/json`, proto3-JSON body.
  - Service string: `instacart.fulfillment.domains.packing.v1.PackagesService`
  - Health: `GET <BASE_URL>/monitors/health` → 200.
- Evidence traced through pumpkin-go: client HTTP adapter `pumpkin/pumpkin-go/rpc/http.go:485`,
  server adapter route prefix `/rpc/` + health `/monitors/health` `pumpkin/pumpkin-go/rpc/http.go:28,143,238`,
  method path `pumpkin/pumpkin-go/internal/rpc/rpc.go:13`.
- grpcurl does NOT apply here (it speaks gRPC/HTTP2). grpcurl is only for FPS's own Go/spice gRPC service (Group 2).
- proto3 JSON conventions: int64 as quoted string, enums as string names, wrapper types (StringValue/Int64Value/BoolValue) as bare scalar, fields lowerCamelCase.

## Endpoint resolution (worked)

- Source: `/home/bento/tf-instacart/groups/fulfillment/fulfillment-providers/terraform.staging.tfvars:19`
  → `rpc_fulfillment_domains_packing_v1_address = "https://rpc-shoppers-shoppers-stg.instacart.team"`.
- Reachability: direct curl from this sandbox WORKS — `GET /monitors/health` → 200. No VPN/mesh hop, no `isc run`/shell fallback needed.
- Auth: WORKS with no auth header (health 200, BulkGetPackages 200, ReplacePackages 200). `AUTH_HEADER=""` in env.sh.

## DevGen provisioning (worked)

- Tool: `devgen-mcp-v2-staging` MCP (reconnected/authorized by team-lead).
- Chain: `create_user` → `generate_order` (Safeway warehouse_ids=[1], service_type "delivery"),
  stopping BEFORE `submit_fulfillment_provider_batch_plan` so FPS is never triggered.
- Result: **order_delivery_id = 20812396763494404**.
- Template: `devgen/provision_group1_order.yaml`.

---

## Live calls + actual responses

Env: `source env.sh` (BASE_URL, ORDER_DELIVERY_ID=20812396763494404, AUTH_HEADER="").
Runner: `./run_case.sh <Method> <request.json>` (substitutes `__ODID__`).

### G1-RP-01 happy full (expect count=2) — PASS
`./run_case.sh ReplacePackages requests/G1-RP-01_happy_full.json` → HTTP 200
`{"totalPackageCount":"2", packages:[id 1102566662 SHELF/A1 CODE_39 BAG-1-OF-2 index1,
  id 1102566663 FREEZER/F3 QR_CODE BAG-2-OF-2 index2], hasAlternativeIdentifier:false}`

### VERIFY BulkGetPackages (expect 2) — PASS
`./run_case.sh BulkGetPackages requests/VERIFY_BulkGetPackages.json` → 2 bags, ids 662/663, all fields round-trip.

### G1-RP-08 resend fewer (expect count=1) — PASS
`./run_case.sh ReplacePackages requests/G1-RP-08_resend_fewer.json` → HTTP 200
`{"totalPackageCount":"1", packages:[id 1102566664 SHELF/A1 CODE_39 BAG-1-OF-1 index1]}`
NOTE: new id 664 (old 662/663 gone) → atomic **delete+recreate**, not in-place update.

### VERIFY BulkGetPackages (expect 1) — PASS
1 bag, id 664 only. Old bags deleted. Replace-on-resend confirmed.

### Other §1.3 cases (all PASS earlier same session, same ODID)
- G1-RP-09 orderDeliveryId "0" → HTTP 400 `{"code":"invalid_argument","msg":"order_delivery_id is required"}` (sole handler validation, packages_service_handler.rb:188).
- G1-RP-06 scan_identifier_type mapping → count=3, CODE_39 / QR_CODE / (absent→UNKNOWN omitted).
- G1-RP-07 location_type enums → count=4, FREEZER/SHELF/FRIDGE/HOT round-trip.
- G1-RP-02 minimal visual-only → 1 bag, only visualIdentifier.
- G1-RP-03 multiple → 4 bags, order preserved; `index` is 1-based (1..4), not 0..3.
- G1-RP-04 empty element `[{}]` → 1 bag, all data fields nil (contrast G1-RP-05).

---

## Finding: G1-RP-05 misclassified in the doc (not a bug)

`./run_case.sh ReplacePackages requests/G1-RP-05_no_array_backfill.json` (no `packages` key)
→ HTTP 200 `{}` (total_package_count=0, 0 rows).
Doc expects "1 backfilled row with has_alternative_identifier=true". That backfill is FPS-side,
NOT RPC: `BuildPackageInputs` returns a single `{HasAlternativeIdentifier: true}` (+ error) when
`len(details)==0` at
`/home/bento/carrot/fulfillment/fulfillment_provider_service/internal/fulfillment_relay_service/service/packages/builder.go:40-48`.
RPC correctly replaces with empty set. Recommend: reclassify G1-RP-05 as [FPS-enforced] (with G1-RP-10..13).

---

## §1.4 BulkUpdatePackages — live run 2026-08-05 (all PASS)

Precondition: G1-RP-01 re-run to give 2 bags (ids 675/676, scan RP01-BARCODE-0001/0002).

- G1-BUP-01 `BulkUpdatePackages requests/G1-BUP-01_pickup_found_at.json` → 200; both bags get
  foundAt (12:00:00Z / 12:00:05Z) + foundVia SCAN_METHOD_SCANNER. BulkGetPackages confirms. PASS.
- G1-BUP-02 `BulkUpdatePackages requests/G1-BUP-02_dropoff_verified_at.json` → 200; both bags get
  verifiedAt (13:00:00Z / 13:00:05Z) + verifiedVia; prior foundAt/foundVia PRESERVED (partial
  update, updatedAt bumped). PASS.
- G1-BUP-04 `BulkUpdatePackages requests/G1-BUP-04_scan_no_match.json` (scan DOES-NOT-EXIST-9999)
  → `{"code":"not_found","msg":"Bag not found: order_delivery_id=20812396763494404 scan_identifier=DOES-NOT-EXIST-9999"}`.
  Post-call BulkGetPackages: both bags STILL have found_at + verified_at → atomic rollback confirmed. PASS.

Behavior notes (source-confirmed): no-match raises ActiveRecord::RecordNotFound inside
Bag.transaction (bag_data_store_adapter.rb:256-268) → handler maps to :not_found
(packages_service_handler.rb:179-180). Partial update only writes keys present per package
(adapter lines 134-137), so found/verified fields don't clobber each other. Handler guards
(line 158-160): order_delivery_id.zero → invalid_argument; empty packages → "packages is
required"; blank scan_identifier → "scan_identifier is required for every package".

No §1.4 divergences from the doc.

## Blockers (all cleared)

- (Cleared) DevGen MCP 401 OAuth → resolved when team-lead reconnected the MCP.
- (Cleared) isc Okta refresh-token invalid → user ran `isc login`; not needed anyway since direct curl works.
- (Cleared) mesh-internal DNS concern → the tf staging address is a public-ish `*.instacart.team` host reachable directly; no `isc run`/shell fallback required.

## Open questions / next step if interrupted

- §1.3 (ReplacePackages) and §1.4 (BulkUpdatePackages) both fully run live — all PASS.
- G1-RP-05 doc reclassification + Group 1 framing split → team-lead is reconciling into the doc centrally.
- Optional: out-of-band `bags` table check via `isc db` proxy (`verify/bags_query.sql`) — BulkGetPackages already served as out-of-band read for every case.
