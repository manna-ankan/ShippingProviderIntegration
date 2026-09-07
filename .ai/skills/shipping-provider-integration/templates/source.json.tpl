// Deterministic stub for a new shippingSource Mongo document.
// Fill every {{PLACEHOLDER}}. Do not invent property keys not listed in
// knowledge/entity-model.md's "Java-known source properties" table unless the key is
// explicitly script-only and documented as such in the IntegrationSpec.
// Do NOT include an "_id" field — see rules/source-rules.md #2.
{
	"code" : "{{PROVIDER_CODE}}",
	"name" : "{{providerDisplayName}}",
	"enabled" : true,
	"created" : ISODate(),
	"updated" : ISODate(),
	"shippingSourceProperties" : [
		{
			"shippingSourceCode" : "{{PROVIDER_CODE}}",
			"name" : "handler.class",
			"value" : "com.uniware.services.shipping.impl.ScrapedShipmentHandler"
		},
		{
			"shippingSourceCode" : "{{PROVIDER_CODE}}",
			"name" : "max.tracking.number.per.request",
			"value" : "{{INTEGER_AS_STRING}}"
		},
		{
			"shippingSourceCode" : "{{PROVIDER_CODE}}",
			"name" : "shipping.payment.method",
			"value" : "{{shippingPaymentMethodCSV}}"
		},
		{
			"shippingSourceCode" : "{{PROVIDER_CODE}}",
			"name" : "available.serviceabilities",
			"value" : "GLOBAL_SERVICEABLITY,LOCATION_AGNOSTIC,LIMITED_SERVICEABILITY"
		},
		{
			"shippingSourceCode" : "{{PROVIDER_CODE}}",
			"name" : "reserved.keywords.for.short.name",
			"value" : "DEMO,PRODUCTION,LTD,PVT"
		},
		{
			"shippingSourceCode" : "{{PROVIDER_CODE}}",
			"name" : "scraper.script",
			"value" : "{{SCRAPER_SCRIPT_NAME}}"
		},
		{
			"shippingSourceCode" : "{{PROVIDER_CODE}}",
			"name" : "tracking.number.allocation.script",
			"value" : "{{TRACKING_NUMBER_ALLOCATION_SCRIPT_NAME}}"
		},
		{
			"shippingSourceCode" : "{{PROVIDER_CODE}}",
			"name" : "tracking.link",
			"value" : "{{trackingLinkUrlOrEmpty}}"
		},
		{
			"shippingSourceCode" : "{{PROVIDER_CODE}}",
			"name" : "tracking.enabled",
			"value" : "1"
			// NOTE: this property uses "1"/"0", NOT "true"/"false" — see entity-model.md's encoding table.
		},
		{
			"shippingSourceCode" : "{{PROVIDER_CODE}}",
			"name" : "reverse.pickup.supported",
			"value" : "{{trueOrFalse_reversePickupSupported}}"
		},
		{
			"shippingSourceCode" : "{{PROVIDER_CODE}}",
			"name" : "pii.masking.enabled.in.template",
			"value" : "<true|false>"
		},
		{
			"shippingSourceCode" : "{{PROVIDER_CODE}}",
			"name" : "api.base.url",
			"value" : "{{API_BASE_URL_FOR_ALLOCATION_AND_LABELS}}"
		},
		{
			"shippingSourceCode" : "{{PROVIDER_CODE}}",
			"name" : "tracking.api.base.url",
			"value" : "{{API_BASE_URL_FOR_TRACKING_SYNC}}"
		}
		// OPTIONAL, add only if applicable — see entity-model.md for the full table and correct encoding:
		// post.manifest.script, forward.shipping.provider.notification.script,
		// reverse.pickup.provider.notification.script, is.shipping.aggregator (uses "1"/"0"),
		// preferred.courier.selection.script (aggregators only), exchange.supported,
		// exchange.shipping.payment.methods, reverse.shipping.payment.methods
		// DO NOT add schedule.pickup.script / pre.configuration.script.name /
		// post.configuration.script.name unless there's an explicit design for them —
		// see entity-model.md, zero worked examples exist in the reference package.
	],
	"shippingSourceConnectors" : [
		{
			"shippingSourceCode" : "{{PROVIDER_CODE}}",
			"name" : "{{PROVIDER_CODE}}_TRACKING_API",
			"displayName" : "{{providerDisplayName}} API",
			"helpText" : null,
			"priority" : 1,
			"requiredInAwbFetch" : true,
			"requiredInTracking" : true,
			"validateInAwbFetch" : true,
			"verificationScriptName" : "{{VERIFICATION_SCRIPT_NAME}}",
			// verificationScriptName is MANDATORY — see rules/connector-rules.md, no skip-verification path exists.
			"shippingSourceConnectorParameters" : [
				{
					"shippingSourceConnectorName" : "{{PROVIDER_CODE}}_TRACKING_API",
					"name" : "{{credentialFieldName}}",
					"displayName" : "{{humanLabel}}",
					"displayPlaceHolder" : "",
					"type" : "TEXT",
					// type must be one of TEXT, PASSWORD, HIDDEN, CHECKBOX, READONLY, LAST_3_CHARS (ShippingSourceConnectorParameter.Type) — no SELECT on connectors, see connector-rules.md.
					"required" : true,
					"priority" : 1,
					"encryptionRequired" : true
				}
				// If a script needs to persist a token/expiry across runs (OAuth, JWT, etc.),
				// declare a HIDDEN + encryptionRequired param here with the EXACT name the
				// verification script's PersistentParams will emit — see connector-rules.md.
			]
		}
	],
	"shippingSourceConfigParameters" : [
		// Tenant-level dropdowns/checkboxes go here (type SELECT/CHECKBOX/TEXT/HIDDEN/FORMULA).
		// This is where provider-specific fixed-choice fields belong — NOT on the connector.
	]
}
