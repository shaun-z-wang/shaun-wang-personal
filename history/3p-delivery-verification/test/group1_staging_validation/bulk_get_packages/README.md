# Group 1 staging validation — PackagesService.BulkGetPackages

Direct Pumpkin-RPC-over-HTTP (Twirp-style) curl against deployed staging. No FPS,
no gRPC, no Sidekiq. READ-only against the shoppers `bags` table.

## Run

```bash
cp env.example.sh env.sh   # fill ODID_A/B/C (already filled with last provisioned ids)
source env.sh
./run_case.sh --list                          # cases + expected results
./run_case.sh requests/G1-BGP-01_single.json  # any case
```

`run_case.sh` always calls `BulkGetPackages`; it substitutes `__ODID_A/B/C__` from `env.sh`.

WARNING: `G1-BGP-10_zero_odid.json` / `G1-BGP-11_zero_mixed.json` reproduce a
full-table seq-scan timeout (Finding #1) — they hang ~30s by design.

## Files
- `cases.tsv` — the suite (same columns as create_delivery_verification/cases.tsv).
- `requests/` — one JSON body per case (templated with `__ODID_A/B/C__`).
- `verify/bags_query.sql` — Blazer/psql out-of-band checks + the EXPLAIN that proves Finding #1.
- `RUNLOG.md` — provisioning recipe, per-case results, findings.
- `env.sh` / `env.example.sh` — endpoint + provisioned order_delivery_ids.

## Provisioned seeds (staging, 2026-08-05)
- ODID_A `20812396763494404` — 2 packages
- ODID_B `20813448721449264` — 3 packages
- ODID_C `20813450726495452` — 0 packages (empty order)
