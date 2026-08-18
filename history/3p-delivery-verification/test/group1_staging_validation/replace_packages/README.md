# Group 1 staging validation — PackagesService.ReplacePackages (no FPS)

Out-of-process client vehicle for validating the **deployed staging**
`PackagesService` RPCs directly, no FPS in the loop. Focus: `ReplacePackages`
(happy path + replace-on-resend), verified out-of-band via `BulkGetPackages`
and the `bags` table.

RPC under test: `instacart.fulfillment.domains.packing.v1.PackagesService`
- handler: `/home/bento/carrot/shoppers/shoppers/domains/packing_domain/app/domain/packing_domain/rpc/packages_service_handler.rb` (`replace_packages`)
- adapter: `/home/bento/carrot/shoppers/shoppers/domains/packing_domain/app/domain/packing_domain/services/data_store_adapters/bag_data_store_adapter.rb`
- proto: `/home/bento/carrot/shared/protos/instacart/fulfillment/domains/packing/v1/packages.proto`

---

## TL;DR — the important correction: this is NOT grpcurl

The task framed the vehicle as **grpcurl**. That is the wrong tool for this RPC.
The shoppers monolith's internal RPC (`PackagesService`) is served by **Pumpkin
RPC over HTTP** (Twirp-style), not gRPC. grpcurl speaks the gRPC/HTTP2 wire
protocol and **cannot call it**. The correct out-of-process client is **curl**.

Evidence (from the Pumpkin source, both ends of the wire):
- Client dial: `rpc.ConnBuilder(...).Build()` →
  `/home/bento/carrot/pumpkin/pumpkin-go/rpc/client.go:136` →
  `NewClientHTTPAdapter` (an **HTTP** client, `http.NewRequest("POST", ...)`),
  `/home/bento/carrot/pumpkin/pumpkin-go/rpc/http.go:485`.
- Server: `ServerHTTPAdapter` handles `POST` with
  `Content-Type: application/json` or `application/protobuf`, health check
  `GET /monitors/health`, route prefix `/rpc/`,
  `/home/bento/carrot/pumpkin/pumpkin-go/rpc/http.go:28,143,238`.
- Wire path = `FullMethodName(serviceName, methodName)` = `<pkg.Service>/<Method>`
  (`/home/bento/carrot/pumpkin/pumpkin-go/internal/rpc/rpc.go:13`), joined under
  `/rpc/`.

So every call is:
```
POST <BASE_URL>/rpc/instacart.fulfillment.domains.packing.v1.PackagesService/<Method>
Content-Type: application/json
<proto3-JSON body>
```
proto3 JSON conventions used in the request files: int64 as a quoted string,
enums as their string names, wrapper types (StringValue/Int64Value/BoolValue) as
the bare scalar, field names in lowerCamelCase.

Why the confusion? The FPS staging doc's `grpcurl -plaintext localhost:5700 ...`
examples target **FPS's own Go/spice service**, which *is* gRPC. The shoppers
monolith it depends on is a different service on a different (HTTP) transport.

---

## Staging access: WORKING — live run executed 2026-08-05

The vehicle ran against **deployed staging**, end to end, no FPS in the loop.

- **Endpoint:** `https://rpc-shoppers-shoppers-stg.instacart.team`
  (resolved from tf-instacart:
  `/home/bento/tf-instacart/groups/fulfillment/fulfillment-providers/terraform.staging.tfvars:19`,
  `rpc_fulfillment_domains_packing_v1_address`). Reachable directly from this
  environment — no VPN/mesh hop needed.
- **Auth:** **no auth header required** from this environment. Health
  (`GET /monitors/health`) → 200; `BulkGetPackages` → 200; `ReplacePackages`
  → 200. `AUTH_HEADER` is empty in `env.sh`.
- **Order provisioned via DevGen MCP** (`devgen-mcp-v2-staging`, reconnected):
  `create_user` + `generate_order` (Safeway warehouse_ids=[1], service_type
  delivery) →
  **`order_delivery_id = 20812396763494404`**. Provisioning stops before the FPS
  batch submit, so FPS is never in the loop (matches Group 1's definition).

### Live results (all real staging output)

| Case | Call | Result | Evidence |
| --- | --- | --- | --- |
| G1-RP-01 | ReplacePackages, 2 pkgs (SHELF/FREEZER, CODE_39/QR) | **PASS** | `{"totalPackageCount":"2",...}` 200; BulkGetPackages round-trips both bags |
| G1-RP-08 | ReplacePackages, 1 pkg (re-send) | **PASS** | `{"totalPackageCount":"1",...}` 200; old bags deleted → atomic replace confirmed |
| G1-RP-09 | ReplacePackages, orderDeliveryId "0" | **PASS** | `{"code":"invalid_argument","msg":"order_delivery_id is required"}` 400 (handler line 188) |
| G1-RP-06 | ReplacePackages, scan_identifier_type mapping | **PASS** | `totalPackageCount:"3"`; CODE_39 / QR_CODE / (absent→UNKNOWN omitted) all correct |
| G1-RP-07 | ReplacePackages, location_type enums | **PASS** | `totalPackageCount:"4"`; FREEZER/SHELF/FRIDGE/HOT round-trip in order |
| G1-BGP-01 | BulkGetPackages (out-of-band verify) | **PASS** | returns replaced packages with correct fields/count each time |

### One finding: G1-RP-05 is misclassified in the doc (not a bug)

G1-RP-05 (ReplacePackages with **no** `packages` array) → `{}` 200
(total_package_count=0, no rows). The doc expects "exactly 1 backfilled row with
`has_alternative_identifier=true`". That backfill is **not** RPC behavior — it
lives in **FPS**: `BuildPackageInputs` returns a single
`{HasAlternativeIdentifier: true}` input (plus an error) when `len(details)==0`,
at `/home/bento/carrot/fulfillment/fulfillment_provider_service/internal/fulfillment_relay_service/service/packages/builder.go:40-48`.
The RPC itself correctly replaces with an empty set. **Recommendation:** move
G1-RP-05 into the `[FPS-enforced]` bucket alongside G1-RP-10..13 (not
RPC-testable), or re-scope it as an FPS-tier case.

---

## How to run (reproduce)

```bash
cd /home/bento/group1_staging_validation/replace_packages
source env.sh   # BASE_URL, ORDER_DELIVERY_ID=20812396763494404, AUTH_HEADER=""
```

Re-provision a fresh order only if needed (the captured id above is live):
run `create_user` + `generate_order` via the DevGen MCP `run_script`
(`devgen/provision_group1_order.yaml`), capture `delivery_id`, set
`ORDER_DELIVERY_ID` in `env.sh`.

Happy path + replace-on-resend + verify:
```bash
./run_case.sh ReplacePackages requests/G1-RP-01_happy_full.json     # total_package_count=2
./run_case.sh BulkGetPackages requests/VERIFY_BulkGetPackages.json  # 2 bags, fields round-trip
./run_case.sh ReplacePackages requests/G1-RP-08_resend_fewer.json   # total_package_count=1 (atomic replace)
./run_case.sh BulkGetPackages requests/VERIFY_BulkGetPackages.json  # 1 bag now
```

Optional out-of-band DB check: `verify/bags_query.sql` over an `isc db` proxy.

Remaining permutations: see `cases.md` (each request file is labeled with its
G1-RP / G1-BGP / G1-BUP case ID and expected result).

## Files
- `run_case.sh` — curl runner: `./run_case.sh <Method> <request_file.json>`.
- `env.example.sh` — copy to `env.sh`; BASE_URL / ORDER_DELIVERY_ID / AUTH_HEADER.
- `requests/` — one proto3-JSON body per case (`__ODID__` is the only token).
- `cases.md` — case matrix (case ID → file → expected).
- `devgen/provision_group1_order.yaml` — DevGen provisioning (stops before FPS).
- `verify/bags_query.sql` — `bags` table verification.

---

## Proposed correction to the e2e test-cases doc (Group 1 framing)

The doc header (`/home/bento/3p_delivery_verification_e2e_test_cases.md`, lines
18-22 and 123) frames Group 1 as *"RPC integration tests ... Implemented as Ruby
RSpec request/handler specs."* That conflates two distinct tiers. Suggested
wording (content, not a full rewrite):

> **GROUP 1 — direct-RPC integration tests (no FPS in the loop).** The test IS
> the caller, invoking the shoppers-monolith RPCs directly and asserting on the
> response + persisted rows. This is the heavy input-permutation layer, and it
> runs in **two tiers**:
> - **1a — local RSpec request/handler specs** (fast, hermetic; the shoppers
>   suite is local-only by design — DATABASE_URL refusal, WebMock seal,
>   destructive Dynamo reset — so it cannot hit staging).
> - **1b — deployed-staging out-of-process calls** for smoke/soak against real
>   infra. Note the shoppers `PackagesService`/`DeliveryVerificationService` are
>   **Pumpkin RPC over HTTP (Twirp-style), not gRPC**, so the staging client is
>   **curl** (`POST /rpc/<pkg.Service>/<Method>`, proto3 JSON) — *not* grpcurl.
>   grpcurl applies only to FPS's own Go/spice gRPC service (Group 2).

Everything else in Group 1 (per-method sub-suites, permutation tables,
FPS-enforced exclusions) stays as-is.
