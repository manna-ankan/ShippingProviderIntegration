# Source rules — filling a `shippingSource` Mongo document

Prescriptive rules derived from `knowledge/entity-model.md` (which has the full citations). This
file states what to *do*; the architecture doc states what was *verified*.

1. **`code`**: uppercase, underscore-separated, unique. Confirmed values in use: `FEDEX2`,
   `SHIPROCKET`, `CLICKPOST`, `BLUEDART`, `DTDC_CUSTOM`. A domestic-vs-international or
   custom-vs-standard variant of an existing provider gets its own distinct code (confirmed pattern:
   `DTDC_CUSTOM` as a distinct source from a presumed standard DTDC integration) — never overload one
   source's properties to branch on a hidden flag.
2. **Do not persist `_id`** in generated source JSON/insert scripts. Production assigns the ObjectId on
   insert; every reference dump shows a pre-existing `_id` only because it was queried back out of a
   live database, not because the insert script set it.
3. **`handler.class`**: default to `com.uniware.services.shipping.impl.ScrapedShipmentHandler` unless
   there's an explicit, ticket-stated reason for custom Java. No reference source uses anything else.
4. **Boolean property encoding is per-property, not uniform** — see the table in
   `knowledge/entity-model.md`. Get it wrong and the flag silently defaults to `false`; nothing
   validates it at insert time. Double-check every boolean property against that table before writing
   it.
5. **`available.serviceabilities`**: copy the value verbatim from a reference source
   (`GLOBAL_SERVICEABLITY,LOCATION_AGNOSTIC,LIMITED_SERVICEABILITY`) including its typo. This is a
   string comparison elsewhere in the platform (not traced this session, but the value is identical
   across all five references, which is itself the signal it must match exactly) — do not "fix" the
   spelling.
6. **`post.manifest.script`**: leave unset (or explicitly set to `""`) if the provider has no
   post-manifest API call. Both forms (Dtdc omits the key; Bluedart sets it to `""`) produce the
   identical runtime outcome (`getPropertyValue` returns `null` either way) — prefer omitting the key
   entirely for a source with no post-manifest behavior, for clarity, since an explicit empty string can
   read as "this was set and is empty" rather than "this doesn't apply."
7. **`schedule.pickup.script` / `pre.configuration.script.name` / `post.configuration.script.name`**:
   these have real getters but zero worked examples in any of the five references. If a ticket requires
   one, flag it as a gap requiring developer design in the `IntegrationSpec` rather than inventing usage
   from the getter's name.
8. **Reverse/exchange capability flags gate downstream validation** — confirmed in
   `ShippingAdminServiceImpl.addShippingProvider` (line 1093 region): reverse/exchange `ShippingMethod`s
   are only accepted for a tenant provider if the source's `reverse.pickup.supported`/
   `exchange.supported` are `true`. If a ticket says "forward only, no reverse," set
   `reverse.pickup.supported: "false"` explicitly (confirmed: `dtdc.json` does exactly this) rather than
   omitting the property — omission and `"false"` behave identically at read time, but an explicit
   `"false"` documents the decision was deliberate.
9. **Naming key**: use `shippingSourceCode`, not `sourceCode`, on every property entry. `sourceCode`
   appears twice across the five reference dumps and is very likely a copy-paste typo the schemaless
   Mongo store tolerated silently — see `knowledge/entity-model.md`'s naming-inconsistency note.
10a. **`max.tracking.number.per.request` — use the provider's real documented batch limit, not a
    guess.** Values directly confirmed against real reference `source.json` dumps this skill's
    knowledge was built from: `50` (Shiprocket, Clickpost), `30` (FedEx), `10` (DTDC). These are
    illustrative data points for calibrating "is this a plausible batch size," not a lookup table —
    the real value must come from the new provider's own API documentation.
10b. **Mandate URL Properties**: Every shipping source must declare its API URLs as static `shippingSourceProperties` (conventionally `api.base.url` for allocation/labels and `tracking.api.base.url` for status sync, with `api.base.staging.url` and `tracking.api.base.staging.url` for testing/staging environments) rather than hardcoding them in scraper XML. Sourcing them from properties ensures the platform can switch environments (staging vs production) without modifying script XML. Pick one consistent naming convention per provider and use it in all scripts.
10c. **Never embed real connector-parameter values as top-level `shippingSourceProperties`.**
    `Ref/Bluedart/bluedart.json` does exactly this — `clientId`/`clientSecret` appear as plaintext
    source-level properties (lines 71-79 of that file), not as connector parameters. This is itself a
    violation of the credential-handling convention every other reference source follows (credentials
    live in `shippingSourceConnectorParameters`, filled per-tenant, not baked into the shared template
    document). Do not replicate this pattern in a new source — see `validation-rules.md`.
10d. **Customer Tracking Link vs API URLs**: Distinguish clearly between `tracking.link` and API URLs:
     - `tracking.link`: The public, human-readable web tracking URL sent to marketplaces (e.g. Flipkart via `msDispatchVerificationScript.xml`) and customers.
     - `tracking.api.base.url` / `tracking.url`: The backend API base URL queried programmatically by the background status sync scraper script.
     Every new shipping source should declare `tracking.link` pointing to the courier's public tracking portal, and the developer should add its AWB concatenation suffix to the platform's `shippingProviderTrackingLinkUtils.xml` script.

