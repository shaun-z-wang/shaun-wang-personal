# RUNLOG — Group 1 staging validation, PackagesService.BulkGetPackages (no FPS)

Durable log of what was provisioned, run, and found. Source of truth for the
final report. No secrets recorded (auth is empty inside the mesh).

Dir: `/home/bento/group1_staging_validation/bulk_get_packages/`
Run date: 2026-08-05.

---

## Status: DONE — live staging run complete. 10 PASS / 2 FAIL (same root cause).

- Endpoint (Pumpkin RPC over HTTP, Twirp-style): `https://rpc-shoppers-shoppers-stg.instacart.team`
- Method: `POST /rpc/instacart.fulfillment.domains.packing.v1.PackagesService/BulkGetPackages`
- Auth: none required from this sandbox (`AUTH_HEADER=""`). Health `GET /monitors/health` -> 200.
- BulkGetPackages is READ, SYNC (direct read of `bags`, no Sidekiq).

---

## Method contract (source-verified)

- Handler `bulk_get_packages`: shoppers/.../rpc/packages_service_handler.rb:41-48.
  - Only guard: `fail! :invalid_argument, "order_delivery_ids is required" if message.order_delivery_ids.empty?`.
  - **No per-odid zero check** — contrast get_packages/create_packages/etc. which
    `fail! :invalid_argument if message.order_delivery_id.zero?`. This omission is Finding #1.
- Adapter `bulk_get_packages`: shoppers/.../services/data_store_adapters/bag_data_store_adapter.rb:55-62.
  - `Bag.where(order_delivery_id: order_delivery_ids).includes(:bag_batch_association)`
    then Ruby-side `.sort_by { [order_delivery_id, index] }` (read via replica-lag-failover).
- Request: `orderDeliveryIds` repeated int64 (proto3 JSON = array of quoted ints).
- Response: flat `packages[]` (Package proto). **No per-delivery grouping message** —
  grouping is implicit via each package's `orderDeliveryId` field + the sort order.

## Provisioning recipe (DevGen MCP `run_script`, no FPS in the loop)

Chain per order: `create_user` -> `generate_order` (warehouse_ids=[1] Safeway,
service_type "delivery", items_found 5). STOPS before any batch-plan submission.
Packages then seeded out-of-band via `ReplacePackages` (the Group 1 write path).

| handle  | order_delivery_id      | packages | how seeded                                        |
|---------|------------------------|----------|---------------------------------------------------|
| ODID_A  | 20812396763494404      | 2        | pre-existing from replace_packages suite (idx1-2) |
| ODID_B  | 20813448721449264      | 3        | ReplacePackages, 3 pkgs BGP-B-0001..3 (idx1-3)    |
| ODID_C  | 20813450726495452      | 0        | order provisioned, never seeded                   |
| (none)  | 999999999999999        | -        | nonexistent sentinel                              |

ODID_A < ODID_B numerically -> used to prove cross-delivery sort is by odid ASC,
not request order.

Seed values live in `env.sh`. Runner: `source env.sh; ./run_case.sh requests/<case>.json`
(substitutes `__ODID_A/B/C__`).

---

## Live calls + actual results

### PASS
- **G1-BGP-01 single** [A] -> 200; 2 rows, idx 1 then 2, ids 675/676, all fields round-trip.
- **G1-BGP-02 multi reversed** [B,A] -> 200; 5 rows returned as A(idx1,2) then B(idx1,2,3)
  even though B was listed first. Confirms sort = order_delivery_id ASC, index ASC.
- **G1-BGP-03 mix populated+empty** [A,C] -> 200; 2 rows (A only); C contributes nothing, no error.
- **G1-BGP-04 zero packages** [C] -> 200; body `{}`; valid delivery with no bags is not an error.
- **G1-BGP-05 nonexistent** [999999999999999] -> 200; body `{}`; silently ignored.
- **G1-BGP-06 large-ish list** [A,B,C,N,+6 nonexistent] -> 200; 5 rows (A+B); 8 empty/nonexistent ignored; ordering held.
- **G1-BGP-07 empty list** [] -> 400 `{code:invalid_argument, msg:"order_delivery_ids is required"}`.
- **G1-BGP-08 omitted field** {} -> 400 same guard (omitted repeated field == empty).
- **G1-BGP-09 duplicate** [A,A] -> 200; 2 rows (not 4); IN(A,A) de-dups.
- **G1-BGP-12 non-numeric** ["not-a-number"] -> 500 `{code:internal, msg:"Encoding error: ... Non-number characters in quoted integer"}`. Codec-layer int64 parse failure, before the handler.

### FAIL — Finding #1
- **G1-BGP-10 zero odid** ["0"] -> request TIMES OUT (curl (28), ~30s, http=000). Reproduced twice.
- **G1-BGP-11 zero mixed** ["0", A] -> also TIMES OUT (http=000). One valid id does not rescue it.

---

## Finding #1 (reliability / DoS): order_delivery_id=0 seq-scans the whole `bags` table

5-whys root cause:
1. `BulkGetPackages(["0"])` never returns within 30s -> curl timeout / RPC hang.
2. The DB query `Bag.where(order_delivery_id: [0])` does a **Seq Scan**, not an index scan.
3. `EXPLAIN SELECT * FROM bags WHERE order_delivery_id = 0` on staging:
   `Seq Scan on bags (cost=0.00..43744533.40 rows=1068132672 width=198)` — planner
   estimates ~1.07B matching rows because 0 is the column default/sentinel (non-selective MCV).
   Contrast a real list: `Index Scan using index_bags_on_order_delivery_id ... rows=1`.
   (A plain Blazer `COUNT(*) WHERE order_delivery_id=0` also times out at 25s.)
4. The value 0 reaches the DB because `bulk_get_packages` only guards `.empty?` — no per-odid
   zero check (packages_service_handler.rb:41).
5. Root cause: the "order_delivery_id zero -> InvalidArgument" invariant enforced on all
   single-id methods was never carried into the repeated-id bulk methods.

Impact: any in-mesh caller (auth is none in staging) can pass `orderDeliveryIds:[0]` — or
accidentally include an unset int64 (0) in a batch — and force a full-table seq scan that
hangs the request and holds a DB/replica connection. Batches that mix 0 with valid ids also hang.

Same class, NOT tested here but sharing the missing-guard shape (both take repeated
order_delivery_ids and only check `.empty?`): `CountPackagesByLocation`
(handler line ~100) and `BulkGetPackageCount`. Recommend auditing all three.

Recommended fix: reject 0 in the bulk methods, e.g.
`fail! :invalid_argument, "order_delivery_ids must not contain 0" if message.order_delivery_ids.any?(&:zero?)`
(and/or `.reject(&:zero?)` before the query).

## Finding #2 (minor, doc/consistency): malformed int64 -> 500, not 400

`["not-a-number"]` returns HTTP 500 `{code:internal}` from the proto3-JSON codec, whereas
semantic validation failures return 400 `{code:invalid_argument}`. Expected for Pumpkin's
JSON decode path (happens before the handler), but worth noting so consumers don't treat
all 5xx as server faults. Not a bug.

## Ordering / grouping conclusion

Confirmed: the response is a single flat `packages[]`, deterministically ordered by
`order_delivery_id ASC` then `index ASC`, independent of the request-list order, with
duplicate ids collapsed and empty/nonexistent ids omitted. Clients that need per-delivery
grouping must group on the `orderDeliveryId` field themselves.

## Out-of-band verification (Blazer, shoppers_staging)

`SELECT order_delivery_id, COUNT(*), MIN(index), MAX(index) ... GROUP BY` over [A,B,C]
returned A=2 (idx1-2), B=3 (idx1-3), C absent — exact match to the RPC. See
`verify/bags_query.sql`.

## Reclassify to Group 2?

Nothing here needs FPS. All 12 cases are pure Group 1 (direct RPC curl). No reclassification.
Finding #1 (missing zero-guard) is a code fix, not a test-grouping change.
