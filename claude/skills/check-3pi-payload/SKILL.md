---
name: check-3pi-payload
description: Audit downstream 3PI consumers when a PR changes an outbound-payload field on the Relay path (customers-backend → integrations). Use when reviewing a PR that adds, populates, or changes a value on an `OutboundOrderItem` / `OutboundOrderLine` field, or any other proto sent from customers-backend to the integrations service. Triggers include "check 3pi payload", "check outbound payload", "review outbound field", or a PR that touches `OutboundOrderLineBuilder` / `outbound_order_line_builder.rb` / any file under `customers/customers-backend/domains/retailer_integrations_domain/app/domain/retailer_integrations_domain/integrations/relay/`.
---

# Check 3PI Payload

Purpose: catch the class of bug where a one-line change on the outbound payload (activating a previously-dormant field, changing the range of values a field can take, populating a `nil`-only field) silently breaks a downstream 3PI plugin whose branch on that field was previously unreachable.

## When to run

- A PR modifies `OutboundOrderLineBuilder#build_outbound_order_line` or any sibling builder that constructs an `OutboundOrderItem` / `OutboundOrderLine` / outbound event proto.
- A PR flips a proto field from "never set" to "sometimes set", or broadens the set of values a field can take (e.g. a boolean that was always `false`/`nil` in practice).
- Any change to `customers/customers-backend/domains/retailer_integrations_domain/app/domain/retailer_integrations_domain/integrations/relay/**`.

## Steps

1. **Name the field(s) the PR changes.** From the diff, list every proto field whose observed distribution shifts (new field populated, `nil` → typed value, narrowed → widened value set). If the PR only reshapes internal typed structs and the wire proto is unchanged, stop — this skill does not apply.

2. **Enumerate consumers in the integrations repo.** For each field name, run:
   ```bash
   grep -rn "<field_name>" /home/bento/carrot/integrations/app --include="*.rb"
   ```
   Ignore spec-only hits for now; focus on production readers under `integrations/app/services/relay/v1/oms_outbound_integration_service/plugins/`. Include both retailer-specific plugins (e.g. `publix/`, `kroger/`) and `relay_default/` / `generic_api/` (these fan out to every generic-API partner). Also grep `integrations/app/services/shared/`.

3. **Read every consumer.** For each hit, read the surrounding method with `Read`. For each consumer, answer three questions:
   1. What was the observed value of this field *before* the PR? (Usually `nil` or a constant.)
   2. What branches / early-returns / short-circuits in this code were **unreachable** under the old value?
   3. When those branches become reachable, what payload does the consumer emit? Does it fall through to a default (e.g. `.to_i` on a non-numeric string returning `0`, an empty string, a stale IC id) that the partner API will reject or misinterpret?

4. **Check test coverage of the newly-reachable branches.** Grep the consumer's spec (`integrations/spec/services/.../plugins/<consumer>/**`) for the specific combination of inputs that becomes newly-possible (e.g. `field=true` + `related_metadata=false` + `no fallback SKU`). If the combination is not covered, flag it — the integrations codebase requires only 80% line coverage and 0% branch coverage, so silent gaps here are the norm.

5. **Write the review.** Structure it as:
   - **Risk verdict**: LOW / MEDIUM / HIGH, one sentence naming the biggest concern.
   - **Consumers**: one section per `file:line` reader. Each section leads with a per-consumer risk label (LOW / MEDIUM / HIGH), then a short prose paragraph covering old-value → new-value → newly-reachable branch → partner-visible consequence, then two labeled bullets:
     - **Gap:** the missing spec case (or "none — covered by …" if adequately tested).
     - **Fix:** the concrete change needed before merge (spec case to add, code to gate, `.compact` semantics to restore, partner to confirm with).
   - Do NOT include a separate "what changes on the wire" section — the PR author already knows what they changed; jump straight to consumers.
   - Do NOT include a separate "test coverage gaps", "ramp / rollback", or "required before merge" section — those points live inside each consumer's Gap/Fix bullets so the reviewer sees risk + evidence + remediation together.

## Anti-patterns to call out

- Reading a proto field's spec-level default (`nil` / `false`) as evidence of consumer safety — the consumer may have coded around the field being unpopulated in *practice* on this specific path, not around the proto default.
- Treating a rollout note in the PR description as sufficient when it names only the *feature-flag* consumer and omits *builder* consumers that read the same field for a different purpose.
- Assuming `relay_default` / `generic_api` consumers are safe because "we own the schema" — the receiving partner does not, and their inbound validators may reject a value they've never seen.

## Output

Show the review inline to the user by default. Only post as a PR comment if the user explicitly asks for it. Do not push code fixes as part of the review pass; the point is to enumerate risk, not to patch it.
