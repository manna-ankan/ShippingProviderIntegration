# Connector rules

Grounded in `ShippingSourceConnector.java` (full read), `ShippingAdminServiceImpl.addOrUpdateShippingProviderConnector`
(method located at `ShippingAdminServiceImpl.java:1568`, key logic spot-verified via grep this session:
`MASKED_PATTERN` at line 200, used at line 1610; `PersistentParams` handling at lines 1678-1695), and the
auth-pattern catalogue in `knowledge/script-engine.md`.

## Connector parameter types

**Authoritative source**: `UniwareCore/src/main/java/com/uniware/core/entity/ShippingSourceConnectorParameter.java`'s
`Type` enum (read directly — this supersedes an earlier draft of this rule that only listed the four
types observed empirically across five sample `source.json` dumps and missed two real ones):

```java
public enum Type {
    TEXT("text"), PASSWORD("password"), HIDDEN("hidden"),
    CHECKBOX("checkbox"), READONLY("readonly"), LAST_3_CHARS("last3chars");
}
```

Six values: `TEXT`, `PASSWORD`, `HIDDEN`, `CHECKBOX`, `READONLY`, `LAST_3_CHARS`. The five reference
`source.json` dumps only exercise the first four — `READONLY` and `LAST_3_CHARS` are real, valid types
with no worked example in the reference package (plausible use: `LAST_3_CHARS` for masked display of a
stored secret, `READONLY` for a platform-computed value shown but not editable — neither confirmed
against actual UI/behavior this session, so don't over-claim their exact semantics beyond the enum
itself). No `SELECT` — dropdowns are consistently modeled as `ShippingSourceConfigParameter`s (tenant
config, not credentials), which do support `SELECT`. If a future connector parameter appears to need a
dropdown, that's a signal it belongs in `shippingSourceConfigParameters`, not
`shippingSourceConnectorParameters`.

`type` (UI widget) and `encryptionRequired` (storage behavior) are independent — confirmed: DTDC's
`apiKey`/`accessToken` are `TEXT`-typed but `encryptionRequired: true`. A field being `HIDDEN` is not
the only way to mark it as a secret; set `encryptionRequired: true` explicitly regardless of `type` for
anything that is actually a credential.

## Runtime flags on `ShippingSourceConnector`

- `requiredInAwbFetch` / `validateInAwbFetch` — read in the AWB-allocation path
  (`AbstractShipmentHandler.scrapeTrackingNumber`, confirmed in the full read of
  `AbstractShipmentHandler.java`: iterates `shippingProvider.getShippingProviderConnectors()`, and for
  each connector where `validateInAwbFetch` is true, calls
  `shippingProviderService.checkIfShippingProviderConnectorIsBroken(connector)` and throws
  `ShippingProviderConnectorException` if broken).
- `requiredInTracking` — read in the tracking path (`ShippingProviderServiceImpl.scrapeShipmentStatuses`,
  confirmed present at line 2268 region via earlier full traversal of that method's surrounding code).
- `verificationScriptName` — **mandatory, no exceptions found**. Confirmed at
  `ShippingAdminServiceImpl.java:1586` region: `addOrUpdateShippingProviderConnector` requires a
  non-blank `verificationScriptName` resolvable in the script cache, else returns `INVALID_SCRIPT`.
  Every one of the five reference connectors sets this field — there is no "skip verification" path in
  the code that was read.

## Credential save flow — what a new connector's verification script MUST do

Confirmed step-by-step from `ShippingAdminServiceImpl.addOrUpdateShippingProviderConnector`:

1. The submitted params are merged with previously-stored values. If an incoming value matches
   `MASKED_PATTERN` (the UI's placeholder for "unchanged secret"), the previously-stored value is
   substituted — the UI never has to resend a real secret it can't display back to the user.
2. The verification script runs live against the provider's real API
   (`verifyAndSyncShippingProviderConnectorParameters`).
3. **On script failure, nothing is persisted** — the connector's error state is set and
   `INVALID_SHIPPING_PROVIDER_CREDENTIALS` is returned. Credentials are only ever persisted on a
   successful live verification call — there is no "save now, verify later" path.
4. On success, submitted params are persisted (encrypted per `encryptionRequired`), **and** any
   `PersistentParams` the script emitted are written back as encrypted connector params — **but only if
   the param name already exists in the source connector's declared parameter list**; otherwise it's
   silently dropped with a log line (confirmed at the lines cited above).

**Rule**: if a verification/allocation script needs to cache a value across runs (an OAuth token, a JWT,
an expiry timestamp), the connector's `shippingSourceConnectorParameters` list **must** declare a
parameter with that exact name (conventionally `type: "HIDDEN"`, `encryptionRequired: true`) before the
script is written to emit it as a `PersistentParam`. Confirmed examples: FedEx declares `accessToken`
and `trackingAccessToken` as `HIDDEN` params and its script emits both by those exact names; Bluedart
declares `JWTToken` and `JWTTokenExpiryDate` the same way. Get the name wrong (or forget to declare it)
and the emitted value is discarded without error.

## Split shipment-vs-tracking credentials: two valid patterns, pick one deliberately

- **FedEx's pattern**: one connector, two parameter pairs (`clientId`/`clientSecret` +
  `trackingClientId`/`trackingClientSecret`), disambiguated inside the script by a `type` variable.
- **Bluedart's pattern**: two separate `ShippingSourceConnector`s (`BLUEDART_TRACKING_API` for AWB
  allocation, `BLUEDART_TRACKING_SYNC_STATUS_API` for tracking-only, with `validateInAwbFetch: false` on
  the second).

Nothing in the Java source prefers one over the other. If a new provider needs this split, state the
choice and the reason in the `IntegrationSpec` — don't default silently, and don't assume the "closest"
reference's choice is required.

## Known gap: some verification scripts referenced by the reference package are absent

`dtdc.json` declares `verificationScriptName: "dtdcCustomUserVerificationScript"` — that file is **not**
present in `Ref/Dtdc/`. `bluedart.json`'s second connector declares
`verificationScriptName: "bluedartScraperVerificationScript"` — also **not** present in `Ref/Bluedart/`.
Neither DTDC nor Bluedart's second connector can be used as a complete worked template for the
verification-script pattern; fall back to FedEx's or Bluedart's first connector's verification script
(both fully present) as the structural template instead.

## Config parameter types — a distinct enum from connector parameter types

`ShippingSourceConfigParameter` (tenant-level dropdowns/checkboxes, not credentials) has its own
`Type` enum, confirmed directly at `UniwareCore/.../entity/ShippingSourceConfigParameter.java:27-32`:
`TEXT`, `HIDDEN`, `CHECKBOX`, `SELECT`, `FORMULA` — five values, distinct from the six-value
`ShippingSourceConnectorParameter.Type` enum above. **`SELECT` exists here, not on connectors** —
this is the confirmation of the "dropdowns belong on config params, not connectors" rule stated
earlier. `ShippingSourceConfigParameter.Group` (its `groupName` field) is a separate two-value enum,
also confirmed directly: `GENERAL`, `OTHERS` (`ShippingSourceConfigParameter.java:12-14`) — no other
group name is valid.
