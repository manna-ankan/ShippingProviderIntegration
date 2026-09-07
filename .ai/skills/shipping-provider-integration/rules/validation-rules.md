# Validation rules

Checks a generated integration (Phase B output) should pass before a developer starts manual testing.
Grounded in the rules files in this directory; this file doesn't introduce new facts, it operationalizes
them into a checklist.

## Mechanical checks (run these first — cheap, automatable, no judgment required)

- [ ] Every generated `.xml` file is well-formed XML (parse with a real XML parser, e.g.
      `xml.dom.minidom` or `xmllint` — do not eyeball tag balance).
- [ ] Every generated `.json` file parses as JSON (or, for `source.json`'s mongo-shell-insert style,
      has balanced braces/brackets — it deliberately isn't strict JSON, see `templates/source.json.tpl`).
- [ ] `IntegrationSpec.json` validates against `schemas/integration-spec.schema.json` with a real
      validator, not by inspection.
- [ ] No unresolved template placeholders remain (`<ANGLE_BRACKET_TOKEN>`-style markers from
      `templates/*.tpl`) in any Phase B output file.
- [ ] No absolute machine paths (user-home-style macOS/Linux paths, Windows drive letters) appear anywhere in generated
      output — grep for them explicitly.
- [ ] No secret-shaped literal (a real credential, token, proxy password, or API key) appears in any
      generated file — see "Secret-handling rule" below for the confirmed real examples to grep for
      specifically, in addition to a general eyeball pass.
- [ ] No hardcoded API URLs in XML scripts — all base/endpoint domains and subdomains must be defined as static properties in `shippingSourceProperties` (conventionally `api.base.url`, `api.base.staging.url`, `tracking.api.base.url`, `tracking.api.base.staging.url`) and resolved dynamically from `#shippingProviderParameters.get('ENVIRONMENT')` (or this ticket's equivalent config key) plus `.getPropertyValue(...)`. Scripts must **not** call `#shippingProvider.getConfigParameter(...)`.
- [ ] No `||` or `&&` inside scraper `#{...}` expressions — Unifier SL rejects `|`; use `or` / `and` or nested `<if>`.
- [ ] No path reference to a local-only file that this run did not actually confirm exists (e.g. a
      claim that a reference provider was read, when no reference path was provided or that
      provider's folder wasn't opened this run) — cross-check every `[REFERENCE-INTEGRATION]`-tagged
      claim in `ANALYSIS.md` against what was actually read this run.
- [ ] Every `shippingSourceConnectorParameters[].type` value is one of the six real
      `ShippingSourceConnectorParameter.Type` values (`TEXT`, `PASSWORD`, `HIDDEN`, `CHECKBOX`,
      `READONLY`, `LAST_3_CHARS`) — no `SELECT`, no invented type string.
- [ ] Every `shippingSourceConfigParameters[].type` value is one of the five real
      `ShippingSourceConfigParameter.Type` values (`TEXT`, `HIDDEN`, `CHECKBOX`, `SELECT`, `FORMULA`),
      and every `groupName` is `GENERAL` or `OTHERS` — both enums confirmed at
      `ShippingSourceConfigParameter.java:12-14,27-32` (see `rules/connector-rules.md`).
- [ ] Every Uniware entity-path expression used in a generated script (`#shippingPackage...`,
      `#invoiceItem...`, etc.) appears in `knowledge/catalogs/uniware-field-expressions.md` or was explicitly
      given by the ticket/API docs — flag anything else as unverified rather than trusting it because
      it "looks plausible."
- [ ] Structural implication checks: `tracking.enabled: "1"` implies `scraper.script` is non-empty;
      `capabilities.createShipment: true` implies `tracking.number.allocation.script` is non-empty;
      `capabilities.cancelShipment: true` implies the corresponding notification-script property is
      non-empty. A capability or flag with no corresponding property is a real defect.
- [ ] **No `scriptError` used as a stand-in for an unresolved unknown.** If a generated script needs
      a Uniware entity path, source property, or platform behavior that isn't confirmed in
      `knowledge/*.md`/`knowledge/catalogs/*.md` and isn't given by the ticket/API docs, the correct
      response during Phase A is a **question**, not a script that compiles but calls `scriptError`
      on an unresolved unknown dressed up as a runtime guard. Distinguish this from a legitimate
      `scriptError` that validates real, ticket-specified business rules (e.g. the HSN-length guard)
      — those are correct and expected.

## Structural validation

- [ ] `source.json` is valid JSON, contains no `_id` field (see `source-rules.md` #2).
- [ ] Every `shippingSourceProperties` boolean value uses the correct per-property encoding (`"1"`/`"0"`
      vs `"true"`/`"false"`) — check against the table in `knowledge/entity-model.md`, not by
      eyeballing.
- [ ] Every required source property the ticket's capabilities imply is actually present — e.g.
      `capabilities.trackShipment: true` requires a `scraper.script` property; `capabilities.cancelShipment: true`
      requires `forward.shipping.provider.notification.script` (and `reverse.pickup.provider.notification.script`
      if reverse is also in scope). A capability marked `true` with no corresponding source property is
      a real defect, not a style nit.
- [ ] Every `shippingSourceConnectorParameters[].name` that a script emits as a `PersistentParam` is
      declared on the connector (see `connector-rules.md`).
- [ ] Every `shippingSourceConnectors[].verificationScriptName` is set and matches a script this task
      actually generates (see `connector-rules.md` — this field is mandatory, not optional).
- [ ] `db.sql` uses `INSERT IGNORE` and subselects `shipment_tracking_status_id` by `code`, never a
      literal numeric id (`db-rules.md`).
- [ ] `db.js` registers a `uniwareScript` + at least one `scriptVersion` row for every script name the
      source references.

## Uniware-specific validation

- [ ] `handler.class` is `com.uniware.services.shipping.impl.ScrapedShipmentHandler` unless the ticket
      explicitly justifies custom Java (`runtime-flow.md`).
- [ ] If `reverse.pickup.supported`/`exchange.supported` is `false` (or unset), no `REVERSE_PICKUP`-type
      status mappings or reverse-flow scripts are generated (`status-mapping-rules.md` rule 3,
      `source-rules.md` #8).
- [ ] Every `<Status>` value a tracking script can emit has a corresponding
      `shipment_tracking_status_mapping` row for this source + type, OR the gap is explicitly flagged as
      an assumption/question rather than silently left to fall through to the code/name fallback tiers
      (`status-mapping-rules.md`).
- [ ] **Status-mapping strategy check**: if the ticket's status-handling instruction conflicts with
      DB-driven mapping (see `status-mapping-rules.md`'s mandatory dual-option gate), confirm this was
      actually surfaced as a conflict with `generationGate: NEEDS_REVIEW` and an explicit approval was
      recorded — a scraper script containing in-line status-translation logic is only valid if Option A
      was explicitly chosen; if no such approval is recorded, in-line translation logic is a defect
      (the gate was silently bypassed), not a stylistic choice.
- [ ] If Option B (raw code passthrough) is what was approved/generated: no scraper script contains
      in-line status-translation logic (if/switch mapping a provider code to a fixed label) — status
      mapping is DB-only.
- [ ] **S3/local-path consistency**: `IntegrationSpec.labelAcquisition.persistedVia` matches what the
      generated allocation script actually does — a spec saying `"local-path-only"` must not produce a
      script that uploads to S3 (or vice versa). This mismatch is easy to introduce by habit (copying a
      prior integration's label-handling code) — check it explicitly, don't assume the template's
      illustrative S3 example was adapted correctly, or removed if not applicable.
- [ ] **Auth-assumption check**: the allocation/tracking/verification scripts' actual auth mechanism
      (header name, value shape, absence of any auth header if credentials are body-embedded) matches
      `IntegrationSpec.authentication.pattern` exactly. A generated `Authorization: Bearer ...` header,
      an OAuth token endpoint, or a JWT-expiry check that the spec's `authentication.pattern` doesn't
      call for is a defect — `templates/scraper-verify.xml.tpl`'s OPTIONS A/B/C exist specifically so
      this doesn't happen by default; confirm the unused options were actually deleted, not left in
      alongside the real one.
- [ ] `available.serviceabilities` matches the exact string (including the production typo
      `GLOBAL_SERVICEABLITY`) used by every reference source encountered during this skill's
      development, if this property is set at all — and is flagged as an assumption (not asserted as
      fact) if the ticket itself doesn't specify it, since it's a business/ops classification, not a
      purely technical constant.

## DB validation

- [ ] SQL syntax is valid (lint/dry-run before handing to a developer).
- [ ] No duplicate `(provider_status, shipping_source_code, type)` combinations within the generated
      `INSERT` statement itself (the `INSERT IGNORE` protects against re-running the script, not against
      internal duplicates in one run).
- [ ] Ordering note is present in the test checklist: Mongo source insert must be applied and confirmed
      visible in the admin UI before the status-mapping SQL is applied (`runtime-flow.md`,
      `db-rules.md`).

## Semantic validation (Jira vs IntegrationSpec vs generated artifacts)

- [ ] Every capability the ticket asks for (create shipment / label / track / cancel / manifest) has a
      corresponding script and source property, or is explicitly listed as unsupported with a reason.
- [ ] Every field the ticket marks mandatory for the provider's API is actually populated in the
      allocation script's request payload.
- [ ] Any conflict between the ticket's description and this knowledge base's rules (the status-mapping
      conflict is the confirmed live example — see `status-mapping-rules.md`) is surfaced as a question,
      not silently resolved in either direction.

## Secret-handling rule (hard requirement, not a suggestion)

Direct inspection this session found two categories of real secret embedded in the existing reference
package:

1. **`Ref/shiprocket/TRACKING_ALLOCATION_VERIFICATION_SHIPROCKET.xml` and
   `Ref/shiprocket/SCRAPER_SCRIPT_SHIPROCKET.xml`** — a hardcoded `vendor_code`/`vendor_token` pair
   (identical long literal string in both places) and a hardcoded residential-proxy
   username/password/host/port in `SCRAPER_SCRIPT_SHIPROCKET.xml:51`.
2. **`Ref/Bluedart/bluedart.json`** — `clientId`/`clientSecret` values embedded in plaintext as
   top-level `shippingSourceProperties` (lines 71-79 of that file), not as connector parameters — itself
   a deviation from the credential-handling convention every other reference source follows.

**Neither of these literal values appears anywhere in this knowledge base**, and none should ever be
copied into a generated artifact, a template, an example, or a future revision of this knowledge base —
not even for illustration. When a pattern like this needs to be documented (e.g. "scripts sometimes
inject a static platform-identification header"), describe the *shape* of the pattern, never the actual
value. This is also why `examples/analysis-report.example.md` uses a fully synthetic provider rather
than any real reference provider's actual data.

If a generation task encounters a real secret anywhere in its inputs (a Jira ticket, an API doc, a
sample payload), mask it in every output using a placeholder (e.g. `<ACCESS_TOKEN>`) — never echo it
back verbatim into a generated file.

## Confidence / gaps this knowledge base already flags — don't re-litigate silently

- `schedule.pickup.script`, `pre.configuration.script.name`, `post.configuration.script.name`: real
  getters, zero worked examples across all five references (`entity-model.md`).
- DTDC's and Bluedart's second connector's verification scripts: referenced by name, absent from
  the reference package (`connector-rules.md`).
- `<retry>` + `<scriptError>` runtime interaction: not fully traceable from source in this repo
  (`script-engine.md`).
- Reference integration package: optional and developer-supplied only; never auto-discovered
  (`PORTABILITY.md`).

A generation run that touches any of these areas should surface the gap as a question, not paper over
it with an assumption presented as fact.
