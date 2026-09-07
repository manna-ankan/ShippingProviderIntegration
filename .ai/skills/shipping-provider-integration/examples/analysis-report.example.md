# Example Phase-A analysis output (synthetic provider — illustrative only)

This is a fabricated example using a fictional courier, **"AcmeExpress"** (code `ACMEEXPRESS`), with
invented API shapes. It is **not** derived from FedEx, Shiprocket, Clickpost, Bluedart, or DTDC's actual
data, and contains no real values from any reference source — see `rules/validation-rules.md` for why.
Its purpose is to show the *shape* Phase A output should take, per `SKILL.md`, not to model any
real provider's fields.

---

## Phase 1 — Understanding

**Provider**: AcmeExpress
**Jira requirements**: Forward shipping only (create shipment, label, track). No reverse pickup, no
cancellation in this phase. `[JIRA]`
**API documentation**: REST/JSON, API key + secret in header, single environment (no
sandbox/staging split documented). `[API-DOC]`
**Required capabilities**: `createShipment: true`, `generateLabel: true`, `trackShipment: true`,
`cancelShipment: false`, `manifest: false`, `reversePickup: false`. `[JIRA]`

## Phase 2 — Uniware mapping

**Uniware flow**: standard `ScrapedShipmentHandler` path — no capability in this ticket requires custom
Java. `[UNIWARE-CODE]` (`knowledge/runtime-flow.md`)
**Applicable source**: new `shippingSource` document, code `ACMEEXPRESS`.
**Applicable connector**: single connector, `ACMEEXPRESS_TRACKING_API` (no split shipment/tracking
credentials mentioned in the docs, so no need for FedEx's or Bluedart's split patterns).
**Applicable services**: `ShippingAdminServiceImpl.addOrUpdateShippingProviderConnector` for tenant
credential save/verify; standard `AbstractShipmentHandler.scrapeTrackingNumber` /
`ShippingProviderServiceImpl.scrapeShipmentStatuses` for allocation/tracking. `[UNIWARE-CODE]`

## Phase 3 — Reference selection

**Closest existing integration**: DTDC (`Ref/Dtdc`) — static long-lived API key, single connector, no
OAuth complexity, matches AcmeExpress's documented single-header-auth model.
**Reason**: `[REFERENCE-INTEGRATION]` DTDC's auth is the simplest precedented pattern that matches
AcmeExpress's docs (static token header, no login call, no expiry logic).
**Differences**: `doNotCopy` — DTDC's verification script (`dtdcCustomUserVerificationScript`) is not
present in `Ref/Dtdc/`, so its exact validation logic can't be copied; only the *pattern* (static token,
no refresh) is reused, built fresh against `templates/scraper-verify.xml.tpl`.

## Phase 4 — IntegrationSpec (excerpt, conforming to `schemas/integration-spec.schema.json`)

```json
{
  "provider": {
    "name": "AcmeExpress",
    "code": "ACMEEXPRESS",
    "closestReferenceIntegration": "dtdc",
    "referenceSelectionReason": "Static long-lived API key auth, single connector — simplest precedented match.",
    "referenceDifferences": "DTDC's own verification script is absent from Ref/; only the static-token pattern is reused, not copied line-for-line."
  },
  "authentication": {
    "pattern": "static-long-lived-token",
    "requiresProactiveExpiryCheck": false
  },
  "capabilities": {
    "createShipment": true,
    "generateLabel": true,
    "trackShipment": true,
    "cancelShipment": false,
    "manifest": false,
    "schedulePickup": false,
    "reversePickup": false,
    "exchange": false,
    "isShippingAggregator": false,
    "multiPartShipment": false
  },
  "statusMappings": [
    {
      "providerStatus": "BOOKED",
      "uniwareStatusCode": "COURIER_ASSIGNED",
      "type": "SHIP_TO_CUSTOMER",
      "confidence": "HIGH",
      "reason": "Explicit 1:1 semantic match in API docs."
    },
    {
      "providerStatus": "OFD",
      "uniwareStatusCode": "OUT_FOR_DELIVERY",
      "type": "SHIP_TO_CUSTOMER",
      "confidence": "MEDIUM",
      "reason": "API docs don't define exact business meaning of OFD vs the courier's separate DISPATCHED code — needs developer confirmation before treating as HIGH."
    }
  ],
  "assumptions": [
    "No sandbox/staging environment exists per docs — verification will run against production credentials."
  ],
  "questions": [
    "Docs don't document what HTTP status a duplicate-order rejection returns — needs a live test call before the allocation script's error branches can be finalized."
  ],
  "confidence": 72,
  "generationGate": "NEEDS_REVIEW"
}
```

## Phase 5 — Risk / ambiguity

**Assumptions**: single environment, no staging.
**Questions**: duplicate-order error shape unconfirmed; `OFD` vs `DISPATCHED` semantic overlap needs
developer confirmation.
**Conflicts**: none identified against this fictional ticket.
**Confidence**: 72% — `generationGate: NEEDS_REVIEW`, not `READY`. Per `SKILL.md`, Phase B
(`source.json`, scripts, `db.sql`, `db.js`) must **not** be generated while any question above is open.

---

*(End of illustrative example. A real analysis report would continue with the full field-mapping table,
full status-mapping list, and full connector-parameter list per `schemas/integration-spec.schema.json`.)*
