<!--
  Deterministic stub for a tracking-number-allocation script (AWB creation + label handling).
  Tag vocabulary confirmed against real scraper scripts read directly during this skill's
  development (see knowledge/script-engine.md for citations; those source files are no longer
  present in this checkout — knowledge/script-engine.md's citations remain the record).

  This template provides STRUCTURE only. Every provider-specific decision below (auth header shape,
  success/failure discriminator, label acquisition mechanism) MUST come from the approved
  IntegrationSpec, never from habit or from whichever reference provider happens to come to mind.
  An iThink-shaped ticket must not accidentally receive Shiprocket- or FedEx-shaped behavior just
  because this template's placeholder comments mention those providers as illustrative examples.

  NEVER hardcode a real credential in this file.
-->
<scraper name="{{TRACKING_NUMBER_ALLOCATION_SCRIPT_NAME}}">

    <var name="JsonUtils" value="#{T(com.unifier.core.utils.JsonUtils)}" />
    <var name="StringUtils" value="#{T(com.unifier.core.utils.StringUtils)}" />
    <var name="shippingSource" value="#{T(com.unifier.core.configuration.ConfigurationManager).getInstance().getConfiguration('shippingSourceConfiguration').getShippingSourceByCode(#shippingProvider.shippingProviderSourceCode)}" />
    <var name="env" value="#{#shippingProviderParameters.get('ENVIRONMENT')}" />
    <if condition="#{'STAGING'.equalsIgnoreCase(#env)}">
        <var name="apiBaseUrl" value="#{#shippingSource.getPropertyValue('api.base.staging.url')}" />
        <else>
            <var name="apiBaseUrl" value="#{#shippingSource.getPropertyValue('api.base.url')}" />
        </else>
    </if>

    <method name="validatePreCallConditions">
        <!-- Fail fast, BEFORE building the request, for anything the provider will otherwise
             reject with a generic error — a scriptError naming the specific offending field/SKU
             and reason, not a blind pass-through. Only include checks the IntegrationSpec actually
             calls for (mandatory-field length/format constraints, zero-value guards, etc.) — do
             not invent validation the ticket/API docs never mentioned. -->
        <!-- <if condition="#{ {{mandatoryFieldCheck}} }">
            <scriptError message="{{skuOrFieldIdentifier}}: {{specificReason}}" />
        </if> -->
    </method>

    <method name="buildRequestBody">
        <!-- Build the create-shipment payload from #shippingPackage / #shippingProviderParameters,
             using ONLY expressions confirmed in knowledge/catalogs/uniware-field-expressions.md or the
             ticket's own field-mapping table — never an invented entity path. Map every mandatory
             field the IntegrationSpec.fieldMappings array declares. -->
        <var name="requestBodyMap" value="#{new java.util.HashMap()}" />
        <!-- <var value="#{#requestBodyMap.put('{{providerField}}', {{verifiedUniwareExpression}})}" /> -->
        <var name="requestBody" value="#{#JsonUtils.objectToString(#requestBodyMap)}" />
    </method>

    <method name="buildAuthHeaders">
        <!-- Derive strictly from IntegrationSpec.authentication.pattern — do not default to
             Bearer/OAuth/JWT. Concrete shapes seen in practice (pick the one the ticket/API docs
             actually describe, or none of these if the real shape differs):

             - static token/API-key header, no prefix:
               <header name="{{ApiKeyHeaderName}}" value="#{#shippingProviderParameters.get('{{apiKeyParamName}}')}" />

             - "Bearer <token>" — only if the API docs literally specify the Bearer scheme:
               <header name="Authorization" value="Bearer #{#shippingProviderParameters.get('{{tokenParamName}}')}" />

             - credentials embedded in the JSON body itself, no auth header at all (e.g. iThink:
               access_token/secret_key are fields inside the request body's "data" object, not
               headers) — buildAuthHeaders may be a no-op in this case; put the credentials into
               buildRequestBody's map instead.

             - per-request signature (HMAC or similar) — compute and attach whatever header names
               the API doc specifies; do not assume a bearer/JWT shape exists underneath it. -->
        <var name="authHeaders" value="#{new java.util.HashMap()}" />
    </method>

    <method name="executeCreateShipment">
        <invoke method="validatePreCallConditions" />
        <invoke method="buildRequestBody" />
        <invoke method="buildAuthHeaders" />

        <http url="#{#apiBaseUrl + '{{CREATE_SHIPMENT_ENDPOINT_PATH}}'}" method="POST" var="createRes" timeout="60" fetchStatusCode="true">
            <header name="Content-Type" value="application/json" />
            <!-- <headers map="#{#authHeaders}" /> if buildAuthHeaders populated one; omit entirely
                 if auth is body-embedded (see buildAuthHeaders comment above). -->
            <body>#{#requestBody}</body>
        </http>

        <try>
            <var name="createResJson" value="#{#JsonUtils.stringToJson(#createRes)}" />
            <catch>
                <scriptError message="Unable to get valid response from the create-shipment API" />
            </catch>
        </try>

        <!-- Never assume HTTP 200 both is-required-for and implies business success — treat the
             two as independent facts, both confirmed from the IntegrationSpec's apis.createShipment
             envelope description:
               - Some providers return non-200 (401/429/5xx) only for transport/auth-level failures.
               - Some providers (documented example: iThink) return HTTP 200 even for a business
                 failure and encode success/failure entirely in a body field — for those, do not
                 gate on #{#createResResponseCode eq 200} at all; check only the body indicator.
             Handle EVERY documented error envelope shape for this specific provider — some
             providers use a different response shape per error code (documented example: iThink's
             1002 failures are flat while 1004 failures are array-wrapped; a template cannot
             anticipate this, the IntegrationSpec's apis.createShipment.errorEnvelope must). -->
        <if condition="#{'{{providerSuccessValue}}'.equalsIgnoreCase(#JsonUtils.getAsString(#createResJson,'{{providerStatusField}}'))}">
            <var value="#{#resultItems.put('trackingNumber', #JsonUtils.getAsString(#createResJson,'{{awbFieldInResponse}}'))}" />
            <var value="#{#resultItems.put('shippingCourier', #JsonUtils.getAsString(#createResJson,'{{courierNameFieldInResponse}}'))}" />
            <!-- If the label comes back INLINE in this same response (documented example: a
                 fictional provider returning label_pdf_base64 alongside the AWB — no separate
                 label call at all), capture it here and skip executeFetchLabel entirely:
                 <var value="#{#resultItems.put('labelInlineBase64', #JsonUtils.getAsString(#createResJson,'{{labelFieldInResponse}}'))}" /> -->
            <else>
                <scriptError message="#{#JsonUtils.getAsString(#createResJson,'{{errorMessageFieldInResponse}}')}" />
            </else>
        </if>
    </method>

    <method name="executeFetchLabel">
        <!-- Only include this method at all if the IntegrationSpec's labelAcquisition says the
             label is a SEPARATE call from shipment creation. Two confirmed-precedented HTTP-level
             mechanisms — pick per what the provider's API actually returns, do not default to one:

             (a) base64 payload embedded in a JSON response → decode to a local file:
                 <var value="#{T(com.unifier.core.utils.EncryptionUtils).base64DecodeToFile(#resultItems.get('labelBase64'), #labelFilePath)}" />

             (b) a URL to GET and stream to disk:
                 <http url="#{#labelUrl}" method="GET" var="downloadLabelRes" timeout="30"
                       fetchStatusCode="true" downloadToFile="#{#labelFilePath}" />
                 <if condition="#{#downloadLabelResResponseCode != 200}">
                     <scriptError message="Unable to download shipping label." />
                 </if>

             Persistence of the downloaded file is a SEPARATE decision from acquisition — driven by
             IntegrationSpec.labelAcquisition.persistedVia, not assumed:

             - "s3-upload": upload via the document service for a durable URL —
                 <var name="labelUrl" value="#{#documentService.uploadFile(new java.io.File(#labelFilePath), #s3BucketName)}" />
                 <var value="#{#resultItems.put('shippingLabelLink', #labelUrl)}" />

             - "local-path-only": store the local path directly, do NOT upload anywhere —
                 <var value="#{#resultItems.put('shippingLabelLink', #labelFilePath)}" />
                 (documented example: a ticket may explicitly require the LOCAL path be persisted
                 and the partner's own hosted URL NOT be persisted — verify this in the spec before
                 defaulting to S3, uploading when the spec says local-only is a real behavior change,
                 not a safe default.) -->
    </method>

    <method name="generateScriptOutput">
        <!-- The tracking number is the script's SCALAR output. -->
        <text value="#{#resultItems.get('trackingNumber')}" />
    </method>

    <method name="main">
        <var name="resultItems" value="#{new java.util.HashMap()}" />
        <invoke method="executeCreateShipment" />
        <!-- <invoke method="executeFetchLabel" /> only if label is a separate call — see above. -->

        <!-- Explicitly copy every key AbstractShipmentHandler reads from #response —
             a value left only in #resultItems is silently dropped. See rules/script-rules.md #5. -->
        <var value="#{#response.put('shippingLabelLink', #resultItems.get('shippingLabelLink'))}" />
        <var value="#{#response.put('shippingCourier', #resultItems.get('shippingCourier'))}" />
        <!-- Only if IntegrationSpec.capabilities.multiPartShipment is true AND the connector has
             an explicit MPS-enable flag — see rules/script-rules.md #10:
             <var value="#{#response.put('childTrackingNumbers', #resultItems.get('childTrackingNumbers'))}" /> -->

        <invoke method="generateScriptOutput" />
    </method>

    <invoke method="main" />
</scraper>
