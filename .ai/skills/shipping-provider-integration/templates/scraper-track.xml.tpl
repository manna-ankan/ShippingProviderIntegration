<!--
  Deterministic stub for a tracking/status-sync script. XML output contract confirmed against a
  real reference script during this skill's development — see knowledge/script-engine.md and
  rules/script-rules.md #4 for citations (that source file is no longer present in this checkout).

  DEFAULT: <Status> carries the provider's RAW status string/code, unmodified — this is the
  DB-table-driven convention (rules/status-mapping-rules.md), confirmed against the actual
  Uniware status-mapping mechanism and every real scraper script inspected during this skill's
  development.

  IF a ticket instead explicitly asks for in-script status-code-to-fixed-label translation, this
  is a Jira-vs-Uniware-convention CONFLICT — do not resolve it here by picking either option.
  Per rules/status-mapping-rules.md, Phase A must set generationGate=NEEDS_REVIEW, present BOTH
  interpretations to the developer, and only fill this template's <Status> line one way or the
  other after explicit approval:
    Option A (literal Jira ask): a <switch>/<if> block here translating {{providerStatusCodeField}}
      to a fixed label chosen by the ticket, with db.sql's provider_status column matching those
      same fixed labels exactly.
    Option B (standard Uniware convention): <Status> emits {{providerStatusCodeField}} verbatim
      (this template's default below), with db.sql's provider_status column matching the raw
      provider codes.
  This template is written for Option B. Do not silently switch it to Option A without the
  conflict having been surfaced and approved first.
-->
<scraper name="{{SCRAPER_SCRIPT_NAME}}">

    <var name="systemZone" value="#{T(java.time.ZoneId).systemDefault()}" />
    <var name="JsonUtils" value="#{T(com.unifier.core.utils.JsonUtils)}" />
    <var name="DateUtils" value="#{T(com.unifier.core.utils.DateUtils)}" />
    <var name="uniwareDatePattern" value="dd-MMM-yyyy HH:mm:ss" />
    <var name="shippingSource" value="#{T(com.unifier.core.configuration.ConfigurationManager).getInstance().getConfiguration('shippingSourceConfiguration').getShippingSourceByCode(#shippingProvider.shippingProviderSourceCode)}" />
    <var name="env" value="#{#shippingProviderParameters.get('ENVIRONMENT')}" />
    <if condition="#{'STAGING'.equalsIgnoreCase(#env)}">
        <var name="trackingApiBaseUrl" value="#{#shippingSource.getPropertyValue('tracking.api.base.staging.url')}" />
        <else>
            <var name="trackingApiBaseUrl" value="#{#shippingSource.getPropertyValue('tracking.api.base.url')}" />
        </else>
    </if>


    <method name="generateXML">
        <startTag name="Shipments" />
            <foreach collection="#{#trackingNumberToStatusMap}" var="entry">
                <startTag name="Shipment" />
                    <var name="trackingNo" value="#{#entry.getKey()}" />
                    <var name="statusData" value="#{#entry.getValue()}" />

                    <!-- Guard the provider's "no value yet" sentinel explicitly before
                         formatting — do not let a date-parse exception abort the whole batch
                         for one AWB. Example precedent: iThink's documented
                         "0000-00-00 00:00:00" sentinel. -->
                    <var name="rawStatusDate" value="#{#statusData.get('{{providerDateField}}').getAsString()}" />

                    <valueTag name="TrackingNumber" value="#{#trackingNo}" />
                    <valueTag name="StatusDate" value="#{#formattedStatusDate}" />
                    <valueTag name="Status" value="#{#statusData.get('{{providerStatusCodeField}}').getAsString()}" />
                    <!-- ^ RAW provider status, verbatim. No if/switch translation here. -->
                <endTag name="Shipment" />
            </foreach>
        <endTag name="Shipments" />
    </method>

    <method name="getTrackingStatus">
        <!-- HTTP shape (per-AWB loop vs one batch call for up to max.tracking.number.per.request
             AWBs; GET vs POST; query params vs JSON body; auth header name and value shape) MUST
             come from the IntegrationSpec's apis.trackShipment description — this per-AWB POST
             loop is one precedented shape, not the only one. A provider whose API accepts a batch
             of AWBs in one call should NOT be forced into a per-AWB loop just because this
             template shows one. -->
        <foreach collection="#{#trackingNumbers}" var="trackingNo">
            <http url="#{#trackingApiBaseUrl + '{{TRACKING_ENDPOINT_PATH}}'}" method="POST" var="trackingRes" timeout="30" fetchStatusCode="true">
                <header name="Content-Type" value="application/json" />
                <!-- Auth header name AND whether credentials go in a header at all (vs the body,
                     vs a signature) come from the connector's real auth pattern — see
                     scraper-verify.xml.tpl's three OPTIONS. Do not assume a generic "accessToken"
                     param name; use the actual connector parameter name declared in source.json. -->
                <header name="{{AuthHeaderName}}" value="#{#shippingProviderParameters.get('{{authParamName}}')}" />
                <body>#{'{"{{providerTrackingNumberField}}":"' + #trackingNo + '"}'}</body>
            </http>

            <!-- Some providers (documented example: iThink) return HTTP 200 even on a logical
                 tracking failure and encode success/failure in a body field — do not gate solely
                 on #{#trackingResResponseCode eq 200} without checking IntegrationSpec.apis.trackShipment's
                 documented envelope first. -->
            <if condition="#{#trackingResResponseCode eq 200}">
                <try>
                    <var name="trackingResJson" value="#{#JsonUtils.stringToJson(#trackingRes)}" />
                    <var value="#{#trackingNumberToStatusMap.put(#trackingNo, #trackingResJson)}" />
                    <catch>
                        <log level="info" value="Invalid response for tracking number: #{#trackingNo}" />
                    </catch>
                </try>
                <else>
                    <log level="info" value="Request failed for #{#trackingNo}, code: #{#trackingResResponseCode}" />
                </else>
            </if>
        </foreach>
    </method>

    <method name="main">
        <var name="trackingNumberToStatusMap" value="#{new java.util.HashMap()}" />
        <invoke method="getTrackingStatus" />
        <invoke method="generateXML" />
    </method>

    <invoke method="main" />
</scraper>
