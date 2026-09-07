# Scraper-script DSL mechanics

Every claim below was checked directly this session by reading full script files (not summarized
secondhand): `Ref/fedex/fedex2UserVerficationScript.xml` (236 lines, full),
`Ref/shiprocket/TRACKING_ALLOCATION_VERIFICATION_SHIPROCKET.xml` (203 lines, full),
`Ref/Dtdc/dtdcCustomScraperScript.xml` (118 lines, full), plus targeted greps against
`Ref/shiprocket/SCRAPER_SCRIPT_SHIPROCKET.xml`, `Ref/shiprocket/TRACKING_NUMBER_ALLOCATION_SHIPROCKET.xml`,
and `Ref/Clickpost/TRACKING_NUMBER_ALLOCATION_GENERIC.xml`.

## Engine identity

This is a custom XML-based DSL ("Unifier Scraper SL"), not Groovy. The runtime classes
(`com.unifier.scraper.sl.*`) are not part of this repository's source tree — they ship in a separate
dependency. This means **the exact runtime semantics of some constructs (notably `<retry>` interacting
with `<scriptError>`) cannot be fully confirmed by reading source in this repo** — see the open question
below. Don't assert behavior for constructs whose implementation isn't visible.

## Envelope

Root element `<scraper name="ScriptName">`. `name` must match the Mongo `uniwareScript` document name
that source properties reference (e.g. `scraper.script`, `tracking.number.allocation.script`,
`verificationScriptName`). Confirmed verbatim in all four fully-read scripts.

## Confirmed tag vocabulary

Directly observed, with the file where each was confirmed:

- `<var name= value=>` — declare/assign. `value` is a `#{...}` Spring-EL-flavored expression.
- `<method name=>...</method>` + `<invoke method=>` / `<invoke method= script="OtherScriptName">` —
  local and **cross-script** method calls. Confirmed: FedEx's script invokes methods in a sibling script
  named `fedexUtils` (not present in `Ref/`); Shiprocket's invokes `userVerificationUtilScript` and
  `globalUtilScript` (also not present in `Ref/`). **Shared utility scripts referenced by name from
  multiple providers' scripts are not themselves in the reference package** — treat their exact behavior
  (e.g. `isTokenValid`, `isCurrentJwtTokenValid`, `getErrorMessageFromJSON`) as inferred from call sites,
  not directly confirmed.
- `<if condition=>` / `<else>` — confirmed nested multiple levels deep in all four scripts.
- `<foreach collection= var=>`, `<while condition=>` — confirmed in DTDC's status-sorting logic and
  Clickpost's MPS/pieces loop.
- `<try>` / `<catch>` — confirmed wrapping every JSON-parse call in all four scripts, always followed by
  a `<scriptError>` with a fixed fallback message on parse failure.
- `<scriptError message=>` — raises an error that aborts the script (confirmed by its universal use as
  the terminal action in every error branch read).
- `<log level= value=>` — `INFO`/`DEBUG`/`info`/`debug` both seen (case is not consistent across
  scripts).
- `<http url= method= var= timeout= fetchStatusCode= fetchResponseHeaders= proxyhost= proxyport=
  proxyusername= proxypassword= downloadToFile=>` with children `<header name= value=>`,
  `<headers map=>` (Shiprocket uses a pre-built map instead of individual `<header>` tags — both forms
  confirmed present in the reference package), `<params map=>` (form-encoded, FedEx's OAuth call),
  `<body>` (raw string, Shiprocket's JSON login body).
  - Response body → `var`-named variable. Status code auto-bound to `{var}ResponseCode` (confirmed:
    `tokenResResponseCode`, `authTokenResResponseCode`, `trackingStatusResResponseCode`).
  - `downloadToFile="#{path}"` streams the response directly to disk instead of capturing it as a string
    — confirmed in Clickpost's label fetch and, importantly, **also in Shiprocket's label fetch**
    (`Ref/shiprocket/TRACKING_NUMBER_ALLOCATION_SHIPROCKET.xml:1561`) followed by an upload to S3 via
    `documentService.uploadFile(...)` and `response.put('shippingLabelLink', s3Url)` — this is a second,
    independently-confirmed example of the "second GET, not base64-in-JSON" label pattern, not unique to
    Clickpost as an earlier draft of this analysis assumed.
  - `proxyhost`/`proxyport`/`proxyusername`/`proxypassword` — confirmed present as literal inline
    attributes on one `<http>` call in `Ref/shiprocket/SCRAPER_SCRIPT_SHIPROCKET.xml:51` (a residential
    proxy vendor's credentials, hardcoded). See `rules/validation-rules.md` — this is a secret embedded
    in script source and must never be copied into this knowledge base or any generated artifact.
- `<retry count= delayInMillis=>` — confirmed wrapping HTTP calls in both `SCRAPER_SCRIPT_SHIPROCKET.xml`
  (`count="3"`) and `TRACKING_NUMBER_ALLOCATION_SHIPROCKET.xml`'s label download (`count="4"`).
- `<startTag name=>` / `<endTag name=>` / `<valueTag name= value=>` — used exclusively to build the
  scraper's XML output (`<Shipments><Shipment>...</Shipment></Shipments>`). Confirmed in full in
  DTDC's `generateXML` method.
- `<text value=>` — sets the script's scalar return value, consumed by the platform as
  `ScriptExecutionContext.getScriptOutput()` — this is how a tracking-number-allocation script returns
  the AWB string. (Referenced in `AbstractShipmentHandler.java`'s call to
  `context.getScriptOutput()`; not itself re-read this session, carried from the earlier full read of
  `AbstractShipmentHandler.java`.)

### Open question: `<retry>` + `<scriptError>` interaction

`Ref/shiprocket/SCRAPER_SCRIPT_SHIPROCKET.xml:36-51` wraps an HTTP call in `<retry count="3"
delayInMillis="200">`, with a `<try>/<catch>` inside that branches on `retryCount` to switch to a proxied
request on retries 2 and 3. The exact excerpt read did not show whether the eventual failure path calls
`<scriptError>` inside the retry loop or after it exits — **this was not fully traced this session** (the
file is large and only the relevant excerpt was read). Do not assume retry-then-scriptError silently
aborts the loop; do not assume it retries cleanly either. If a new script needs this pattern, read the
full method before copying it, and treat the DSL runtime's behavior here as something to verify by
testing, not by reading XML.

## Auth patterns catalogue (all four confirmed by full read except DTDC's connector, confirmed via `dtdc.json` + `dtdcCustomScraperScript.xml`)

| Provider | Pattern | Confirmed mechanics |
|---|---|---|
| FedEx | OAuth2 client-credentials | `POST {baseUrl}/oauth/token`, `grant_type=client_credentials`, **two separate credential pairs** (`clientId`/`clientSecret` for shipment scope, `trackingClientId`/`trackingClientSecret` for tracking scope) in **one connector**. Proactive expiry check via cross-script `isTokenValid` (10-minute buffer, `tokenExpireBufferInMin`), re-checked on every verification run unless `userTriggeredVerification` forces a fresh token. 401 → fixed message "Invalid API Key or Secret Key..."; 429 → fixed rate-limit message. New/refreshed tokens written back via `<ConnectorParams><PersistentParams><Name>accessToken</Name><Value>...</Value></PersistentParams></ConnectorParams>` in `generateScriptOutput`. |
| Shiprocket | Email/password login, **proactively expiry-checked** (not merely "refresh if blank" as an earlier draft of this analysis stated — `main()` unconditionally calls `isCurrentJwtTokenValid` with a 10-minute buffer before deciding whether a new token is needed) | `POST {baseUrl}/v1/external/auth/login` with `{email, password, vendor_code, vendor_token}` (the last two are a **hardcoded Unicommerce-platform secret literal**, not tenant credentials — see validation-rules.md). Every subsequent call also injects a static `Unicommerce: ACCESS_TOKEN:...` header carrying the same literal value. Token stored via the same cross-script `PersistentParams` convention (`userVerificationUtilScript.generateScriptOutput`). |
| DTDC | Static long-lived token, no refresh logic in the two scripts present | `accessToken`/`apiKey` are plain connector params (`TEXT` type, but `encryptionRequired: true`), injected as `X-Access-Token` header. `dtdcCustomScraperScript.xml` reads `accessToken` straight from `shippingProviderParameters` with zero validity check or refresh call. The verification script that would presumably mint/refresh this token (`dtdcCustomUserVerificationScript`, per `dtdc.json`'s `verificationScriptName`) **is not present in `Ref/Dtdc/`** — DTDC cannot be used as a template for a refreshable-token flow. |
| Bluedart | JWT-style login, client-side expiry | Two **separate connectors** for shipment-vs-tracking credentials (`BLUEDART_TRACKING_API`, `BLUEDART_TRACKING_SYNC_STATUS_API`) — a structurally different choice from FedEx's "two param pairs, one connector." `JWTToken`/`JWTTokenExpiryDate` stored as `HIDDEN`+encrypted connector params via the same `PersistentParams` convention (not directly re-read this session at the XML level for the JWT script's login-call mechanics, but the params confirmed present in `bluedart.json`). The second connector's verification script (`bluedartScraperVerificationScript`) is referenced by name but **not present in `Ref/Bluedart/`**. |
| Clickpost | Generic aggregator pattern (structurally similar to the above — verification script + connector params), not re-verified at the XML level this session beyond the MPS/label-download excerpts | — |

Two structurally different answers exist in the reference package for "split shipment vs tracking
credentials" (FedEx: one connector, two param pairs; Bluedart: two connectors). Neither is "more
correct" per anything confirmed in the Java source — `ShippingSourceConnector` supports both shapes
equally. Pick one per new integration and state the reason in the `IntegrationSpec` rather than
defaulting silently.

## Reading platform context inside a script

Confirmed pattern across all scripts read: `#{#shippingProviderParameters.get('paramName')}` (the flat
merged map of connector params + config params + any runtime `PersistentParams`),
`#{#shippingPackage...}` / `#{#reversePickup...}` domain objects, and — for **source-level static
properties** (not tenant params) — re-resolving the `ShippingProviderSource` via
`T(com.unifier.core.configuration.ConfigurationManager).getInstance().getConfiguration('shippingSourceConfiguration').getShippingSourceByCode(#shippingProvider.shippingProviderSourceCode)`
then calling `.getPropertyValue('...')` on it. Confirmed verbatim in `dtdcCustomScraperScript.xml:103`
(used to pick `tracking.link` vs `staging.tracking.link` based on a `live` connector param).

**Never read source-config params via `#shippingProvider.getConfigParameter('...')`.** That method
walks `ShippingProvider.shippingProviderConfigParameters`, a lazy Hibernate collection. Scraper
execution has no session, so this throws `LazyInitializationException` (confirmed live on
ITHINK_INTERNATIONAL verification, 2026-08-25). Uniware already copies those config values into
`#shippingProviderParameters` before the script runs (`AbstractShipmentHandler` /
`ShippingProviderServiceImpl`). Read them the same way as connector params:

```xml
<var name="env" value="#{#shippingProviderParameters.get('ENVIRONMENT')}" />
```

The config param *name* is whatever `source.json` declared (`ENVIRONMENT` with STAGING/PRODUCTION,
or DTDC's `live` with TRUE/FALSE). Do not copy DTDC's `live` flag unless this ticket actually uses
that shape — copy only the *read path*.

## Boolean operators in `#{...}` expressions

The Unifier Scraper SL compiler **rejects `|` (ASCII 124)**. Java/SpEL `||` therefore fails
script load with `ScriptCompilationException: Cannot handle (124) '|'`. Use the DSL keywords
`or` and `and` (confirmed in domestic iThink and Shiprocket), or nest `<if>` / `<else>` instead
of a ternary.

Do **not** write:

```xml
<var name="x" value="#{#a || #b}" />
<if condition="#{#a == null || #b}">
```

Do write:

```xml
<if condition="#{#a == null or #b}">
```

```xml
<var name="env" value="#{#shippingProviderParameters.get('ENVIRONMENT')}" />
<if condition="#{'STAGING'.equalsIgnoreCase(#env)}">
    <var name="apiBaseUrl" value="#{#shippingSource.getPropertyValue('api.base.staging.url')}" />
    <else>
        <var name="apiBaseUrl" value="#{#shippingSource.getPropertyValue('api.base.url')}" />
    </else>
</if>
```

Prefer nested `<if>` for environment URL selection — it avoids both `||` and a compact ternary.
`&&` should be written as `and` the same way.

## Writing the script's output

Confirmed pattern: internal work accumulates into a locally-scoped `resultItems` map, then at the end:
(a) `<text value="#{#resultItems.get('trackingNo')}"/>` (or equivalent) sets the scalar script output
consumed as the tracking number, and (b) selected keys are separately copied into the actual `#response`
map (`response.put('shippingLabelLink', ...)`, confirmed in Shiprocket's label-download flow;
`resultItems.put('childTrackingNumbers', ...)`, confirmed in Clickpost's MPS flow). **Not every key
written to `resultItems` is necessarily copied to `#response`** — verify per-script that every value
`AbstractShipmentHandler` reads (`shippingLabelLink`, `shippingLabelFormat`, `shippingCourier`,
`expectedDeliveryDate`, `childTrackingNumbers`) is actually written to `#response`, not left sitting only
in `resultItems`.

## Tracking script XML output contract

Confirmed byte-for-byte from `dtdcCustomScraperScript.xml`'s `generateXML` method:

```xml
<Shipments>
  <Shipment>
    <TrackingNumber>...</TrackingNumber>
    <StatusDate>...</StatusDate>   <!-- format dd-MMM-yyyy HH:mm:ss, confirmed via explicit
                                         DateTimeFormatter.ofPattern in the script -->
    <Status>...</Status>            <!-- the courier's RAW status string/code, verbatim.
                                         See rules/status-mapping-rules.md — this is never
                                         translated to a Uniware status inside the script. -->
  </Shipment>
</Shipments>
```

## Error handling convention

Universal pattern across every script read: (1) HTTP call with `fetchStatusCode="true"`; (2)
`<try><var .../JsonUtils.stringToJson(raw)/><catch><scriptError message="Unable to get valid response
from the X API"/></catch></try>` for parse failures; (3) explicit status-code branches (200/202 happy
path, 401 → fixed "invalid credentials" message, 429 → fixed rate-limit message where handled); (4) a
generic fallback that extracts a best-effort message from the provider's JSON error shape via a
cross-script helper, with a hardcoded `defaultMessage` fallback ("Error received from Fedex. Please
connect with their team" — this exact phrasing is provider-specific literal text, confirmed verbatim).
