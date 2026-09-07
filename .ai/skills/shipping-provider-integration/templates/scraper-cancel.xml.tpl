<!--
  Deterministic template for a shipment cancellation script (forward or reverse notification).
  XML output contract: must emit <CancelOnProvider><CancellationStatus>Success/Failure</CancellationStatus></CancelOnProvider>.
-->
<scraper name="{{CANCELLATION_SCRIPT_NAME}}">

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

    <method name="generateXML">
        <startTag name="CancelOnProvider" />
            <if condition="#{#cancellationSuccess == true}">
                <valueTag name="CancellationStatus" value="Success" />
                <else>
                    <valueTag name="CancellationStatus" value="Failure" />
                </else>
            </if>
        <endTag name="CancelOnProvider" />
    </method>

    <method name="cancelShipment">
        <!-- Adapt request body format to provider requirements -->
        <var name="requestBody"><![CDATA[{
            "tracking_number": "#{#shippingPackage.trackingNumber}"
        }]]></var>

        <http url="#{#apiBaseUrl}/{{CANCELLATION_ENDPOINT}}" method="POST" var="response" timeout="30" fetchStatusCode="true">
            <header name="Content-Type" value="application/json" />
            <header name="Authorization" value="Bearer #{#shippingProviderParameters.get('{{API_KEY_PARAM_NAME}}')}" />
            <body>#{#requestBody}</body>
        </http>

        <if condition="#{#responseResponseCode == 200}">
            <try>
                <var name="responseJson" value="#{#JsonUtils.stringToJson(#response)}" />
                <!-- Evaluate success condition per provider API schema -->
                <var name="cancellationSuccess" value="#{#responseJson.get('success').getAsBoolean()}" />
                <catch>
                    <scriptError message="[REQUEST_FAILED] : Failed to parse response received from provider" />
                </catch>
            </try>
            <else>
                <scriptError message="[REQUEST_FAILED] : AWB cancellation request failed with status: #{#responseResponseCode}" />
            </else>
        </if>
    </method>

    <method name="main">
        <invoke method="cancelShipment" />
        <invoke method="generateXML" />
    </method>

    <invoke method="main" />
</scraper>
