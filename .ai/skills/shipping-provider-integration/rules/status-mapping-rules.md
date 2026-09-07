# Status mapping rules

This is the most heavily re-verified rule in this knowledge base, because it directly contradicts a
description in `jira.md`'s example ticket. Every claim below was independently confirmed this session
by reading the actual entity, the actual cache implementation, the actual consumer, and a real scraper
script's actual output — not carried over from any prior unverified analysis.

## The mechanism, confirmed end to end

**Entity** (`UniwareCore/src/main/java/com/uniware/core/entity/ShipmentTrackingStatusMapping.java`,
full file read this session): `@Table(name = "shipment_tracking_status_mapping")`, fields
`id`, `shipmentTrackingStatus` (`@ManyToOne` FK), `shippingSourceCode`, `providerStatus`, `type`,
`providerDescription`.

**Cache build** (`ShippingConfiguration.addShipmentTrackingStatus`,
`UniwareServices/src/main/java/com/uniware/services/configuration/ShippingConfiguration.java:173-194`,
read directly this session): for every `ShipmentTrackingStatusMapping` row on a `ShipmentTrackingStatus`,
builds `providerToProviderStatusToTypeToShipmentTrackingStatus[sourceId][providerStatus.toUpperCase()][type]
= shipmentTrackingStatus`. Lookups are **case-insensitive** on `providerStatus` (both write and read
sides `.toUpperCase()` it, confirmed at lines 190 and 248).

**Lookup API** (`ShippingConfiguration.java:245-259`, read directly):
```java
public ShipmentTrackingStatus getMappedShipmentTrackingStatus(String shippingProviderSourceId, String providerStatus, String type)
public String getMappedProviderDescription(String shippingProviderSourceId, String providerStatus, String type)
```

**Consumer** (`ShipmentTrackingServiceImpl.doUpdateShipmentTracking`,
`UniwareServices/src/main/java/com/uniware/services/shipping/impl/ShipmentTrackingServiceImpl.java:196-203`,
read directly this session) — confirmed **three-tier fallback**, tier 1 always tried first:

```java
trackingStatus = shippingConfiguration.getMappedShipmentTrackingStatus(
        sourceConfiguration.getShippingSourceByCode(shippingProvider.getShippingProviderSourceCode()).getId(),
        providerStatus.getStatus(), shipmentTracking.getType());
if (trackingStatus == null) {
    trackingStatus = shippingConfiguration.getShipmentTrackingStatusByCode(providerStatus.getStatus());
}
if (trackingStatus == null) {
    trackingStatus = shippingConfiguration.getShipmentTrackingStatusByName(providerStatus.getStatus());
}
```

Tier 1's lookup key is the `ShippingProviderSource`'s Mongo `_id` (its `getId()`), **not** the source
code string and **not** the tenant `ShippingProvider` id. Get the wrong id into a generated mapping row
and the lookup silently misses, falling through to tiers 2/3.

**`type` values**: confirmed the full enum directly —
`UniwareCore/src/main/java/com/uniware/core/entity/ShipmentTracking.java:31-35`:
```java
public enum Type { SHIP_TO_CUSTOMER, REVERSE_PICKUP, RETURN_TO_ORIGIN }
```
`doUpdateShipmentTracking` branches on exactly these three string values (confirmed at line 209 region).

**Producer side — what a scraper script actually emits**: confirmed directly in
`Ref/Dtdc/dtdcCustomScraperScript.xml`'s `generateXML` method (full file read): the `<Status>` tag is
populated with `#{#trackingStatus}`, which is `trackingData.get('strCode').getAsString()` — DTDC's raw
provider status **code**, verbatim, with zero in-script translation. No `if`/`switch` branch anywhere in
that script maps a provider code to a Uniware status name or code.

## The rule

**Status mapping is exclusively DB-table-driven** (`shipment_tracking_status_mapping` rows, inserted via
`db.sql`/migration, read through the `ShippingConfiguration` cache at runtime). A scraper script's job is
to emit the courier's raw status string/code into `<Status>` — nothing more. It must never contain
if/switch logic that translates a provider code into a Uniware status code or maps it to a fixed English
label standing in for a Uniware status.

## Documented conflict — mandatory dual-option gate, never resolve silently

A real ticket (PI-8529, iThink Logistics International — encountered directly in this skill's
development) demonstrates a recurring conflict shape: the ticket describes exactly the opposite of
the rule above — "the script emits its own fixed label per code rather than passing through
iThink's wording" and "**Full-journey emission** — all 17 codes emit... and the script emits its
own fixed label per code."

Every piece of evidence this skill has directly verified against the actual codebase — the
`ShipmentTrackingStatusMapping` entity, the `ShippingConfiguration` cache, `ShipmentTrackingServiceImpl`'s
lookup, and a real reference script's actual behavior (DTDC's, before its source file was removed
from this checkout — see `knowledge/catalogs/`/`knowledge/script-engine.md` for the citation trail) — says
mapping should be DB-table-driven, with the script only ever surfacing the courier's literal status
string. Per the source-of-truth hierarchy in `SKILL.md` (Uniware Java contracts are tier 1, above
Jira at tier 2), a Jira instruction that conflicts with a **confirmed** Java/architecture fact does
not automatically win just because it's more specific to this ticket — but it also does not
automatically lose. **Neither side is silently preferred.**

**This is a hard procedural rule, not just a recommendation to flag conflicts in general:**

Whenever a ticket's status-handling instruction conflicts with the DB-driven mapping mechanism
confirmed above, Phase A MUST:

1. Identify the conflict explicitly in `conflicts[]`.
2. Present **both** interpretations in the `IntegrationSpec`, not just describe the conflict in
   prose:
   - **Option A — follow Jira literally**: in-script `provider_status_code → fixed_label`
     translation (e.g. a `<switch>` block), with `db.sql`'s `provider_status` column matching those
     same fixed labels exactly.
   - **Option B — follow the standard Uniware mapping convention**: the script emits the provider's
     raw status code/string verbatim; `db.sql`'s `provider_status` column matches the raw codes;
     zero in-script translation logic. This is what every independently-confirmed real scraper
     script actually does.
3. Set `generationGate: "NEEDS_REVIEW"` (never `READY`) while this is unresolved.
4. **Do not generate `SCRAPER_SCRIPT_*`'s `<Status>` line, nor the corresponding `db.sql` rows,
   until a developer has explicitly chosen A or B.** Generating a best-guess version of either and
   presenting it as the output is exactly the silent-resolution failure mode this rule exists to
   prevent — a lower-confidence placeholder is not an acceptable substitute for asking.
5. After explicit approval of A or B, generate exactly that option — do not generate "a bit of
   both" or silently substitute B for A because B seems safer. If the developer picks A, generate
   the in-script translation faithfully to the ticket's fixed-label table, and note in
   `VALIDATION.md` that this departs from every other confirmed reference pattern and must be kept
   in lockstep with `db.sql` by hand.

This same procedure applies to **any** future ticket describing script-hardcoded status labels, not
just PI-8529 specifically — PI-8529 is the confirmed worked example, not a one-off special case.

## Practical rules for generating `shipment_tracking_status_mapping` rows

1. `provider_status` = the exact raw string/code the provider's API returns (case doesn't matter for the
   lookup, but match the provider's actual casing for readability and `provider_description`).
2. `shipping_source_code` = the new source's `code` (matches `ShippingProviderSource.code`, not the
   tenant `ShippingProvider`'s code).
3. `type` = one of `SHIP_TO_CUSTOMER`, `REVERSE_PICKUP`, `RETURN_TO_ORIGIN` — nothing else.
4. Map to a `shipment_tracking_status.code` that already exists in the platform's status list — see
   `knowledge/catalogs/uc-tracking-statuses.md` for a verified-but-partial allowlist (real codes
   confirmed present in git-tracked `build_*.sql` migrations and Java constants; not the full
   production table). If a needed code isn't in that list, search `build_*.sql` directly or query the
   live table before assuming it doesn't exist. Do not invent new UC status rows unless the ticket
   explicitly requires a platform status change — that's a larger, out-of-scope change from a single
   courier-integration ticket.
5. Insert order matters: per `knowledge/runtime-flow.md`, the `shippingSource` Mongo document must be
   visible in the running server's cache before status-mapping SQL referencing its `shippingSourceCode`
   is inserted, or the cache-reload-and-retry logic in `ShippingConfiguration.addShipmentTrackingStatus`
   will hard-fail with `RuntimeException("Invalid Shipping Source code: ...")` after one retry.
