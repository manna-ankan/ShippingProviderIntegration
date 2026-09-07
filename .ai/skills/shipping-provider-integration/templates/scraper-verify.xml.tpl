<!--
  Deterministic stub for a connector verification script. Tag vocabulary confirmed against real
  scraper scripts read during this skill's development — see knowledge/script-engine.md for
  citations (those source files are no longer present in this checkout; the citations are the
  record).

  DO NOT default to an OAuth/JWT/Bearer/token-refresh shape. Pick the pattern that matches what the
  Jira/API documentation ACTUALLY describes for THIS provider. Three structurally different, equally
  valid starting points are sketched below — delete the two you don't need, do not keep all three as
  "coverage."

  NEVER hardcode a real credential, proxy password, or platform token in this file. Every
  {{PLACEHOLDER}} below must come from a connector parameter, not a literal.
-->
<scraper name="{{VERIFICATION_SCRIPT_NAME}}">

    <var name="StringUtils" value="#{T(com.unifier.core.utils.StringUtils)}" />
    <var name="shippingSource" value="#{T(com.unifier.core.configuration.ConfigurationManager).getInstance().getConfiguration('shippingSourceConfiguration').getShippingSourceByCode(#shippingProvider.shippingProviderSourceCode)}" />
    <var name="env" value="#{#shippingProviderParameters.get('ENVIRONMENT')}" />
    <if condition="#{'STAGING'.equalsIgnoreCase(#env)}">
        <var name="apiBaseUrl" value="#{#shippingSource.getPropertyValue('api.base.staging.url')}" />
        <var name="trackingApiBaseUrl" value="#{#shippingSource.getPropertyValue('tracking.api.base.staging.url')}" />
        <else>
            <var name="apiBaseUrl" value="#{#shippingSource.getPropertyValue('api.base.url')}" />
            <var name="trackingApiBaseUrl" value="#{#shippingSource.getPropertyValue('tracking.api.base.url')}" />
        </else>
    </if>


    <method name="validateConnectors">
        <!-- Fail fast on blank required connector params before making any HTTP call. -->
        <if condition="#{#StringUtils.isEmpty(#{{requiredCredentialParam}})}">
            <scriptError message="{{humanReadableFieldName}} is required." />
        </if>
    </method>

    <!-- ============================================================================
         OPTION A — static, long-lived credentials (API key, secret, or similar).
         The most common shape for providers with no described login/token endpoint at
         all — every request simply carries the stored credential value(s) directly.
         If this is the right option, verification is just: validate non-blank, then
         make ONE real, low-side-effect API call to confirm the provider accepts them
         (pick an endpoint from the documented API surface with minimal side effects —
         do not invent a "verify credentials" endpoint the docs don't describe; if no
         low-side-effect call exists, say so as a Phase A question rather than guessing
         one). No PersistentParams needed — there is nothing to cache or refresh.
    ============================================================================ -->
    <method name="verifyStaticCredentials">
        <http url="#{#trackingApiBaseUrl + '{{DOCUMENTED_LOW_SIDE_EFFECT_ENDPOINT_PATH}}'}" method="POST" var="verifyRes" timeout="30" fetchStatusCode="true">
            <header name="Content-Type" value="application/json" />
            <body>#{{{minimalRequestBodyPerDocumentedContract}}}</body>
        </http>
        <try>
            <var name="verifyResJson" value="#{T(com.unifier.core.utils.JsonUtils).stringToJson(#verifyRes)}" />
            <catch>
                <scriptError message="Unable to get valid response while verifying credentials" />
            </catch>
        </try>
        <!-- Check whatever the provider's documented success/failure indicator actually is —
             do not assume HTTP 200 alone means the credentials were accepted. -->
    </method>

    <!-- ============================================================================
         OPTION B — login/token-issuing call (email+password, client-credentials, or
         similar) that returns a token to cache. Only use this shape if the API
         documentation actually describes such an endpoint.
    ============================================================================ -->
    <method name="generateScriptOutput">
        <!-- Emits the token back to the platform. The connector MUST declare a parameter
             with this exact name (type HIDDEN, encryptionRequired true) or the value is
             silently discarded — see rules/connector-rules.md. -->
        <startTag name="ConnectorParams"/>
            <if condition="#{#newAccessTokenGenerated}">
                <startTag name="PersistentParams"/>
                    <valueTag name="Name" value="{{accessTokenParamName}}"/>
                    <valueTag name="Value" value="#{#accessToken}"/>
                <endTag name="PersistentParams"/>
            </if>
        <endTag name="ConnectorParams"/>
    </method>

    <method name="executeGetToken">
        <!-- POST to whatever login/token endpoint the API docs describe, with whatever body
             shape they specify (client-credentials grant, email+password, or other) — do not
             assume OAuth2's specific grant_type/field-name conventions unless the docs use
             OAuth2. -->
        <http url="#{#tokenUrl}" method="POST" var="tokenRes" timeout="30" fetchStatusCode="true">
            <header name="Content-Type" value="application/json" />
            <body>#{#tokenRequestBody}</body>
        </http>

        <try>
            <var name="tokenResJson" value="#{T(com.unifier.core.utils.JsonUtils).stringToJson(#tokenRes)}" />
            <catch>
                <scriptError message="Unable to get valid response from the token API" />
            </catch>
        </try>

        <if condition="#{#tokenResResponseCode eq 200}">
            <var name="accessToken" value="#{T(com.unifier.core.utils.JsonUtils).getAsString(#tokenResJson,'{{tokenFieldNameInResponse}}')}" />
            <if condition="#{#StringUtils.isEmpty(#accessToken)}">
                <scriptError message="Invalid response from {{PROVIDER_NAME}}, empty token received." />
            </if>
            <var name="newAccessTokenGenerated" value="#{true}" />
            <else>
                <if condition="#{#tokenResResponseCode eq 401}">
                    <scriptError message="Error Code : #{#tokenResResponseCode} Error Message : Invalid API Key or Secret Key. Please revalidate connector parameter" />
                    <else>
                        <scriptError message="Unexpected error from {{PROVIDER_NAME}} while generating token." />
                    </else>
                </if>
            </else>
        </if>
    </method>

    <!-- Whether to proactively re-check expiry vs only refresh-when-blank is a real design
         choice (both are precedented) — state which one in the IntegrationSpec, don't default
         to either. Proactive: check a stored expiry timestamp against now + a buffer, every run.
         Refresh-when-blank: only call executeGetToken if #accessToken is currently empty. -->

    <!-- ============================================================================
         OPTION C — per-request signing (HMAC or similar), no token issued or cached at
         all. Verification is: validate non-blank credentials, compute the documented
         signature for a real low-side-effect call, confirm it's accepted. No
         PersistentParams — nothing to cache. Do not invent the signing algorithm; it
         must come from the API documentation.
    ============================================================================ -->
    <!-- <method name="computeSignature"> ... per the documented algorithm exactly, e.g.
         HMAC-SHA256 over a documented string-to-sign, using T(javax.crypto.Mac) /
         T(javax.crypto.spec.SecretKeySpec) via the DSL's confirmed T(...) static-type
         access — UNVERIFIED whether this specific javax.crypto combination executes inside
         the Unifier Scraper SL runtime; treat as needing a runtime test before trusting it
         in production, not as a confirmed-working pattern. </method> -->

    <method name="main">
        <var name="newAccessTokenGenerated" value="#{false}" />
        <invoke method="validateConnectors" />

        <!-- Call exactly ONE of verifyStaticCredentials / executeGetToken (with its own
             expiry-check logic) / a signature-based check, per whichever OPTION above matches
             this provider's real auth contract. -->

        <invoke method="generateScriptOutput" />
    </method>

    <invoke method="main" />
</scraper>
