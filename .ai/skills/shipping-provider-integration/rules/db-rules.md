# DB script rules (`db.js` / `db.sql`)

Grounded in the actual top-level templates (a Shiprocket-International example, read directly)
plus `knowledge/runtime-flow.md`'s cache-staleness
finding and `rules/status-mapping-rules.md`'s DB-driven mapping mechanics.

## What `db.js` inserts, confirmed from the actual template

The existing template (a Shiprocket-International example) does three things, in this order:

1. **`db.uniwareScript.insertOne({...})`** — one per script name, with `script: ""` (an empty shell —
   the actual XML is loaded separately, not embedded in this insert), `enabled: true`, a `version`
   string tied to the ticket (e.g. `"PI-8401"`), `editableByCustomerSupport: false`.
2. **`db.scriptVersion.insertOne({...})`** — one per script name **per tenant that needs it pinned to
   this specific version**, matching the `uniwareScript` version string.
3. **A bulk loop** — `db.tenantProfile.find({ tenantCode: { $nin: [...] } }).forEach(...)` inserting a
   `scriptVersion` row per tenant at version `"1.0"` (a different, presumably "current stable" version
   marker distinct from the ticket-specific version used in step 2) for every tenant except an explicit
   exclusion list.

This confirms two distinct concerns that generated `db.js` must keep separate: (a) registering that a
script *exists* (`uniwareScript`), and (b) pinning *which version* a given tenant should run
(`scriptVersion`). A script with no `scriptVersion` row for a tenant is presumably not resolvable for
that tenant at runtime (not independently re-verified this session at the Java level — inferred from the
template's own two-step structure, which wouldn't otherwise need both inserts).

## What `db.sql` inserts, confirmed from the actual template

```sql
INSERT IGNORE INTO shipment_tracking_status_mapping
  (provider_status, shipment_tracking_status_id, shipping_source_code, type, provider_description)
VALUES
  ("pickup_scheduled", (SELECT id FROM shipment_tracking_status WHERE code = "PICKUP_PENDING"), "BEINGSHIPS", "SHIP_TO_CUSTOMER", ""),
  ...
```

Confirmed conventions from the template:
- **`INSERT IGNORE`** — makes the script idempotent against re-running (duplicate `provider_status` +
  `shipping_source_code` + `type` combinations are silently skipped rather than erroring). There must be
  a unique constraint backing this for `IGNORE` to have any effect — not independently re-verified at
  the schema level this session, but the template's exclusive use of `INSERT IGNORE` here (never plain
  `INSERT`) is itself the signal to follow the same convention.
- **`shipment_tracking_status_id` is a subselect**, not a hardcoded numeric id — `(SELECT id FROM
  shipment_tracking_status WHERE code = "...")`. This is the correct pattern: numeric ids are not stable
  across environments (dev/staging/prod), status codes are.
- Rows come in matched pairs — one `SHIP_TO_CUSTOMER` set and a structurally parallel
  `REVERSE_PICKUP` set with the same provider-status strings mapped to the `CIR_*`-prefixed reverse
  equivalents (`CIR_PICKUP_PENDING`, `CIR_IN_TRANSIT`, etc.) — confirmed in the template. A forward-only
  provider (no reverse pickup support) should **not** generate the `REVERSE_PICKUP` half of this pattern
  — see `status-mapping-rules.md` rule 3 and the source's `reverse.pickup.supported` flag.

## Ordering rule (the one that actually breaks if violated)

Per `knowledge/runtime-flow.md`: the `shippingSource` Mongo document (or, in the template's case, an
existing source's `shippingSourceCode`) must already be visible in the running server's
`ShippingSourceConfiguration` cache before `shipment_tracking_status_mapping` rows referencing that
`shipping_source_code` are inserted and reloaded. `ShippingConfiguration.addShipmentTrackingStatus`
attempts one cache reload if the source isn't found, then throws `RuntimeException` if it's still
missing. Generated `db.js`/`db.sql` for a brand-new source should therefore document (in the test
checklist, not enforce programmatically — these are two separate scripts run manually) that the Mongo
insert must be applied and confirmed visible before the SQL insert is applied.

A second, narrower ordering constraint applies within the Mongo side itself: `uniwareScript` rows
should exist (even as empty `script: ""` shells) before the `shippingSource` document's properties
reference their names — a source property pointing at a script name with no corresponding
`uniwareScript` document is expected to leave that capability non-functional until the script is
created, though the exact runtime error text for this specific case was not independently confirmed
against Java source this session (plausible based on the general pattern, not verified) — treat it
as a strong convention, not a hard-confirmed exception message. Recommended insert order: (1)
`uniwareScript` rows, (2) `shippingSource` document, (3) `scriptVersion` rows for tenants in scope,
(4) `shipment_tracking_status_mapping` rows.

## What a generated `db.js`/`db.sql` pair should and shouldn't do

- Do: insert `uniwareScript` shells for every new script name the `IntegrationSpec` declares, with
  `script: ""` (the actual XML is a separate deliverable — see `templates/scraper-*.xml.tpl`).
- Do: insert `scriptVersion` rows scoped to whichever tenants are actually in scope for the ticket. Don't
  default to "all tenants" unless the ticket says platform-wide rollout (the `jira.md` example ticket
  explicitly states "enabled for all tenants... not gated to a pilot" — that's a ticket-specific fact,
  not a default to assume for every future ticket).
- Do: use `INSERT IGNORE` for `shipment_tracking_status_mapping` rows, and subselect the status id by
  `code`, never a literal numeric id.
- Don't: insert `ShippingProvider`/`ShippingProviderConnector` RDBMS rows — those are tenant-admin
  actions taken later through the UI/API, not part of the Mongo-template-plus-status-mapping deliverable
  (see `knowledge/entity-model.md`).
- Don't: embed real credentials, tokens, or any other secret value anywhere in `db.js`/`db.sql` — see
  `validation-rules.md`.
