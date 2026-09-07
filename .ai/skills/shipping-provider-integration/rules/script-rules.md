# Scraper-script authoring rules

Prescriptive distillation of `knowledge/script-engine.md` (which has the full citations). Read that
file first if a rule here needs justification.

1. **Envelope**: `<scraper name="ExactScriptName">...</scraper>`. `name` must exactly match the
   `uniwareScript` document name referenced by the source's `scraper.script` /
   `tracking.number.allocation.script` / `verificationScriptName` properties.
2. **Never hardcode secrets in script XML.** Two confirmed real examples of what not to do:
   `Ref/shiprocket/TRACKING_ALLOCATION_VERIFICATION_SHIPROCKET.xml` embeds a `vendor_code`/`vendor_token`
   pair as literal request-body values, and `Ref/shiprocket/SCRAPER_SCRIPT_SHIPROCKET.xml:51` embeds a
   residential-proxy username/password as literal `<http>` attributes. Both are committed, plaintext,
   script-source secrets. Any credential a script needs — including platform-level ones, not just
   tenant-provider ones — belongs in a connector parameter (or, if it's truly a fixed platform secret
   unrelated to any one tenant, that's a design smell worth raising, not copying).
3. **Auth**: pick the pattern that matches the provider's actual API, not the pattern of whichever
   reference is topically closest. OAuth2 client-credentials (FedEx's shape), email/password login
   (Shiprocket's shape), static long-lived token (DTDC's shape), and JWT-login-with-client-expiry
   (Bluedart's shape) are all precedented — see the catalogue in `knowledge/script-engine.md`. Whatever
   is chosen, if a token/expiry needs to persist across runs, declare a matching `HIDDEN` connector
   parameter first (see `connector-rules.md`) — the platform silently drops an emitted `PersistentParam`
   whose name isn't declared.
4. **Tracking/status script output contract** (verified byte-for-byte against DTDC's `generateXML`):
   ```xml
   <Shipments><Shipment>
     <TrackingNumber>...</TrackingNumber>
     <StatusDate>...</StatusDate>   <!-- dd-MMM-yyyy HH:mm:ss -->
     <Status>...</Status>            <!-- the provider's RAW status string/code, unmodified -->
   </Shipment></Shipments>
   ```
   Never put translated/mapped status text in `<Status>` — see `status-mapping-rules.md`. If the
   provider's date sentinel for "no value yet" isn't a normal empty/null (e.g. iThink's documented
   `0000-00-00 00:00:00`), guard for it explicitly before formatting, rather than letting a date-parse
   exception abort the whole tracking batch for that AWB.
5. **Allocation script output contract**: accumulate into a locally-scoped `resultItems` map during
   processing; at the end, (a) set the scalar script output (the tracking number) via `<text
   value="...">`, and (b) explicitly copy every value `AbstractShipmentHandler` actually reads —
   `shippingLabelLink`, `shippingLabelFormat`, `shippingCourier`, `expectedDeliveryDate`,
   `childTrackingNumbers` — into `#response`. A value left only in `resultItems` and never copied to
   `#response` is silently lost; this is a confirmed footgun (Shiprocket and Clickpost both do the copy
   explicitly; verify a new script does too rather than assuming it happens automatically).
6. **Label acquisition**: two confirmed working patterns, pick based on what the provider's API actually
   returns —
   - **Base64-in-JSON**: decode to a local file, then upload via the document service to get a durable
     URL (FedEx's shape).
   - **Second HTTP GET, `downloadToFile`**: stream the label URL straight to disk (`<http method="get"
     downloadToFile="#{path}">`), then — confirmed in Shiprocket's script, not just Clickpost's — upload
     the downloaded file to S3 and put the resulting URL into `#response`. Don't leave the label only as
     a local temp-file path in `#response`; both confirmed reference scripts upload it to get a durable,
     servable URL.
7. **Error handling**: wrap every JSON-parse in `<try>/<catch>` with a `<scriptError>` fallback message;
   branch explicitly on HTTP status codes you know the meaning of (401 → credentials, 429 → rate limit)
   rather than lumping every non-200 into one generic message; if the provider's error shape isn't
   flat (e.g. iThink's documented split between a flat 1002 shape and an array-wrapped 1004 shape), parse
   defensively for both rather than assuming one envelope.
8. **Mandate source-level API URLs (Do NOT hardcode URLs)**: Scraper scripts must never contain hardcoded API endpoints, domains, or base URLs. All API base URLs (e.g., `api.base.url`, `tracking.api.base.url`) must be declared as static properties in `shippingSourceProperties` (see `rules/source-rules.md` #10b) and read at runtime from the `ShippingProviderSource` via `.getPropertyValue(...)`. Pick production vs staging from the **config param already merged into `#shippingProviderParameters`** — never `#shippingProvider.getConfigParameter(...)` (lazy-collection / no Session). Nested `<if>` on `ENVIRONMENT` (or this ticket's equivalent name):

   ```xml
   <var name="env" value="#{#shippingProviderParameters.get('ENVIRONMENT')}" />
   <if condition="#{'STAGING'.equalsIgnoreCase(#env)}">
       <var name="apiBaseUrl" value="#{#shippingSource.getPropertyValue('api.base.staging.url')}" />
       <else>
           <var name="apiBaseUrl" value="#{#shippingSource.getPropertyValue('api.base.url')}" />
       </else>
   </if>
   ```

   STAGING/PRODUCTION as a SELECT is valid. Do not replace it with DTDC's `live` TRUE/FALSE unless the ticket uses that shape.
8a. **Facility → pickup/warehouse code resolution**: confirmed exact call, directly verified against
   `UniwareCore/.../entity/Facility.java:271` (`public String getFacilityAlias(String code,
   FacilityAlias.SourceType sourceType)`) and `FacilityAlias.java:27-29`
   (`enum SourceType { ..., SHIPPING_PROVIDER }`):
   ```
   #{#shippingPackage.facility.getFacilityAlias(#shippingProviderCode, T(com.uniware.core.entity.FacilityAlias.SourceType).SHIPPING_PROVIDER)}
   ```
   Use this exact signature whenever a provider needs a per-facility pickup/warehouse code resolved via
   Facility Alias, with a connector-param fallback and a hard `scriptError` if neither resolves — this
   was previously only asserted as an unverified pattern (carried from a ticket's prose, not checked
   against source); it is now directly confirmed.
9. **Before treating any construct as "safe to copy," check it was actually confirmed** in
   `knowledge/script-engine.md`. Specifically: the exact interaction between `<retry>` and
   `<scriptError>` was **not** fully traced this session (the DSL runtime is closed-source and the
   relevant script excerpt wasn't read to its conclusion) — if a new script needs retry-with-fallback
   behavior, verify by testing, don't assume the XML reads the way it looks.
10. **Multi-part shipments (MPS)**: only populate `childTrackingNumbers` if the provider's API actually
    returns per-piece AWBs and the connector has an explicit MPS-enable flag (confirmed pattern:
    Clickpost's `IS_MPS_ENABLED` connector param gates the whole `childTrackingNumbers` code path). Don't
    populate it speculatively "in case it's needed" — an empty/absent list is the correct default.
11. **Cancellation script output contract**: Any forward or reverse shipment cancellation script (e.g. `forward.shipping.provider.notification.script` / `reverse.pickup.provider.notification.script`) must output a well-formed XML block matching the following contract:
    ```xml
    <CancelOnProvider>
        <CancellationStatus>Success</CancellationStatus> <!-- Value must be "Success" or "Failure" -->
    </CancelOnProvider>
    ```
    Root-level bound variables available inside the cancellation script are `#shippingPackage` (representing the package being cancelled, which exposes `#shippingPackage.trackingNumber` and `#shippingPackage.code`), `#shippingProvider`, and `#shippingProviderParameters`. Base URL properties should be resolved dynamically using `#shippingProviderParameters.get('ENVIRONMENT')` (or the ticket's equivalent config key) — never `#shippingProvider.getConfigParameter(...)`.
12. **Dynamic SpEL/Expression Evaluation**: When a connector parameter contains a dynamic expression reference (e.g. `ORDER_ID_REFERENCE` or a custom reference number formula), the script must wrap and evaluate the expression using the `SLExpression` parser:
    ```xml
    <var name="refExpression" value="#{#shippingProviderParameters.get('ORDER_ID_REFERENCE')}" />
    <if condition="#{T(com.unifier.core.utils.StringUtils).isBlank(#refExpression)}">
        <var name="refExpression" value="#shippingPackage.saleOrder.displayOrderCode" />
    </if>
    <invoke method="evaluateReferenceNumber" />
    ```
    Where `evaluateReferenceNumber` compiles the expression using:
    `T(com.unifier.scraper.sl.expression.SLExpression).compile(#refExpression).evaluate(T(com.unifier.scraper.sl.runtime.ScriptExecutionContext).current())`
13. **NPE-proof Cache Lookups**: When resolving state names from location cache (especially for international shipments where codes might be missing or country-specific), always check if the cached object is null before invoking any methods (like `.getName()`), and fall back to raw database address state names or codes:
    ```xml
    <var name="stateObj" value="#{T(com.unifier.core.cache.CacheManager).getInstance().getCache('locationCache').getStateByCode(#stateCode, #countryCode)}" />
    <if condition="#{#stateObj != null}">
        <var name="stateName" value="#{#stateObj.getName()}" />
        <else>
            <var name="stateName" value="#{#shippingPackage.shippingAddress.state.name}" />
        </else>
    </if>
    ```
14. **Rounding Precision & Path Safety**:
    - Multi-line item value calculations (unit value) should use half-even rounding (BigDecimal division with rounding mode `6`).
    - Label PDF local file downloads should be saved using an MD5-encoded unique filename inside the dedicated `/shippingLabel` subdirectory to prevent file system naming collisions.
15. **Boolean operators**: Unifier Scraper SL **cannot compile `|`**. Never use Java `||` or `&&` inside `#{...}` / `condition="#{...}"`. Use `or` / `and`, or nest `<if>`/`<else>`. Confirmed load failure: `ScriptCompilationException: Cannot handle (124) '|'`.
16. **Config params**: Read tenant source-config values only from `#shippingProviderParameters.get('PARAM_NAME')`. `#shippingProvider.getConfigParameter('PARAM_NAME')` throws `LazyInitializationException` (no Hibernate session in the scraper). Connector params use the same map.


