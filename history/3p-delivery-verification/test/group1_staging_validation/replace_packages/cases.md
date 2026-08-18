# Group 1 case matrix — PackagesService (staging, no FPS)

Method column is the Pumpkin RPC method to pass to `run_case.sh`. Every request
file uses the single template token `__ODID__` (substituted with `$ORDER_DELIVERY_ID`).

**Live run 2026-08-05** against `https://rpc-shoppers-shoppers-stg.instacart.team`,
order_delivery_id `20812396763494404`, no auth header, no FPS. Status column
reflects real staging output.

## §1.3 ReplacePackages (write) — the focus

| Case | Method | Request file | Status | Expected / observed |
|------|--------|--------------|--------|---------------------|
| G1-RP-01 | ReplacePackages | requests/G1-RP-01_happy_full.json | **PASS** | 2 bags; `totalPackageCount:"2"`; BulkGetPackages round-trips visual_identifier, scan_identifier_type (CODE_39, QR_CODE), location_type (SHELF, FREEZER), ids assigned. |
| G1-RP-08 | ReplacePackages | requests/G1-RP-08_resend_fewer.json | **PASS** | Run AFTER G1-RP-01. Old 2 bags deleted, 1 new bag created atomically; `totalPackageCount:"1"`. Replace-on-resend / atomic delete+recreate confirmed. |
| G1-RP-09 | ReplacePackages | requests/G1-RP-09_invalid_odid.json | **PASS** | `orderDeliveryId "0"` → `{"code":"invalid_argument","msg":"order_delivery_id is required"}` 400; nothing persisted. (The one validation the handler performs, line 188.) |
| G1-RP-06 | ReplacePackages | requests/G1-RP-06_scan_type_mapping.json | **PASS** | `totalPackageCount:"3"`; scan_identifier_type maps CODE_39 / QR_CODE / (absent→UNKNOWN omitted). |
| G1-RP-07 | ReplacePackages | requests/G1-RP-07_location_type_enums.json | **PASS** | `totalPackageCount:"4"`; FREEZER/SHELF/FRIDGE/HOT round-trip in order. |
| G1-RP-02 | ReplacePackages | requests/G1-RP-02_minimal_visual_only.json | **PASS** | 1 bag; only visualIdentifier set; no scanIdentifier/locationType. |
| G1-RP-03 | ReplacePackages | requests/G1-RP-03_multiple_packages.json | **PASS** | 4 bags; `totalPackageCount:"4"`; payload order preserved. Note: `index` is **1-based** (1..4), not 0..3. |
| G1-RP-04 | ReplacePackages | requests/G1-RP-04_no_meaningful_data.json | **PASS** | Array with one empty element → 1 bag persisted with only id/type/index, all data fields nil; `totalPackageCount:"1"`. Contrast G1-RP-05 (no array → 0 rows). |
| G1-RP-05 | ReplacePackages | requests/G1-RP-05_no_array_backfill.json | **MISCLASSIFIED** | RPC returns `{}` 200 (0 rows). Doc's "1 backfilled row" is FPS-side (builder.go:40-48), not RPC. Reclassify as FPS-enforced. |

Not RPC-testable (FPS-enforced before the call): G1-RP-10 empty details array,
G1-RP-11 missing visual_identifier, G1-RP-12 invalid location_type, G1-RP-13
already-submitted skip. These belong to Group 2 / FPS unit tests, per the doc.

## §1.5 BulkGetPackages (read) — verification vehicle

| Case | Method | Request file | Expected |
|------|--------|--------------|----------|
| G1-BGP-01 | BulkGetPackages | requests/VERIFY_BulkGetPackages.json | Returns all bags for the ODID; scan_identifier_type, visual_identifier, has_alternative_identifier round-trip faithfully from the DB. Use after each ReplacePackages call to confirm state + count. |

## §1.4 BulkUpdatePackages — live run 2026-08-05 (precondition: G1-RP-01 = 2 bags)

| Case | Method | Request file | Status | Expected / observed |
|------|--------|--------------|--------|---------------------|
| G1-BUP-01 | BulkUpdatePackages | requests/G1-BUP-01_pickup_found_at.json | **PASS** | Both bags (scan RP01-BARCODE-0001/0002) get `foundAt` + `foundVia:SCAN_METHOD_SCANNER`; BulkGetPackages confirms. |
| G1-BUP-02 | BulkUpdatePackages | requests/G1-BUP-02_dropoff_verified_at.json | **PASS** | Both bags get `verifiedAt` + `verifiedVia`; prior `foundAt`/`foundVia` PRESERVED (partial update, no clobber). |
| G1-BUP-04 | BulkUpdatePackages | requests/G1-BUP-04_scan_no_match.json | **PASS** | Unknown scan → `{"code":"not_found","msg":"Bag not found: ... scan_identifier=DOES-NOT-EXIST-9999"}`; post-verify state UNCHANGED → atomic rollback (whole tx). Handler line 179-180 maps RecordNotFound→not_found. |

Handler validations not separately cased but confirmed by reading
`packages_service_handler.rb:158-160`: order_delivery_id.zero → invalid_argument;
empty packages → "packages is required"; any blank scan_identifier →
"scan_identifier is required for every package".
