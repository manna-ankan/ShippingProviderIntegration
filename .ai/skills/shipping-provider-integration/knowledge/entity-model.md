# Entity model: template vs tenant instance

Verified directly against `UniwareCore/src/main/java/com/uniware/core/entity/ShippingProviderSource.java`,
`ShippingSourceConnector.java`, and spot-checked method signatures in
`UniwareServices/src/main/java/com/uniware/services/shipping/impl/ShippingAdminServiceImpl.java`.

There are two layers. Conflating them is the most common way to misdesign a new integration.

| Layer | Entity | Store | Scope | Created by |
|---|---|---|---|---|
| Template / global definition | `ShippingProviderSource` | MongoDB, collection `shippingSource` | One doc per courier product (e.g. `FEDEX2`, `SHIPROCKET`, `BLUEDART`, `DTDC_CUSTOM`), shared across all tenants | Hand-authored Mongo insert (`db.js`-style). **No Java API in this codebase creates a `shippingSource` document.** |
| Template / connector definition | `ShippingSourceConnector` + `ShippingSourceConnectorParameter` | Embedded in the same Mongo doc | Declares what credential fields exist and which script verifies them | Same Mongo doc, authored alongside the source |
| Tenant instance | `ShippingProvider` | RDBMS | One row per tenant that enables the source | `ShippingAdminServiceImpl.addShippingProvider` — confirmed at `ShippingAdminServiceImpl.java:1093` |
| Tenant credentials | `ShippingProviderConnector` + `ShippingProviderConnectorParameter` | RDBMS | One row per `ShippingSourceConnector` declared on the source, per tenant | `addShippingProvider` seeds one connector per source connector at `Status.NOT_CONFIGURED`; values filled by `addOrUpdateShippingProviderConnector` — confirmed at `ShippingAdminServiceImpl.java:1568` |
| Tenant method mapping | `ShippingProviderMethod` | RDBMS | Per-`ShippingMethod` config (tracking-number generation strategy) | Part of the `addShippingProvider` request |

**Consequence**: a new-provider task produces the Mongo template doc (`shippingSource` + connectors +
config params) and the associated scraper scripts. It does not produce SQL to insert `ShippingProvider`
or `ShippingProviderConnector` rows — those are tenant-admin actions taken later, through the UI or the
APIs above, using the source as a template.

## `ShippingProviderSource` fields

Confirmed directly from `ShippingProviderSource.java:57-70`:

```java
private String  id;
private String  code;                 // @Indexed(unique = true)
private String  name;
private boolean hidden;
private boolean enabled;
private Date    created;
private Date    updated;
private Set<ShippingSourceConnector>        shippingSourceConnectors;
private Set<ShippingProviderSourceProperty> shippingSourceProperties;
private Set<ShippingSourceConfigParameter>  shippingSourceConfigParameters;
```

`shippingSourceProperties` is a flat name/value bag (`ShippingProviderSourceProperty`, one row =
`{shippingSourceCode, name, value}`). Java only knows about the property names it has a typed getter
for (see below); anything else is script-only and read at runtime via
`shippingSource.getPropertyValue('...')`.

`code` is `@Indexed(unique = true)` in Mongo — but see `knowledge/runtime-flow.md` for why that
uniqueness constraint alone doesn't make a newly-inserted source immediately usable (cache staleness).

## Java-known source properties (typed getters — confirmed one-by-one against `ShippingProviderSource.java`)

| Property key | Getter | Encoding | Line |
|---|---|---|---|
| `handler.class` | `getHandlerClassName()` | string | 176 |
| `scraper.script` | `getScraperScript()` | string | 204 |
| `tracking.number.allocation.script` | `getTrackingAllocationScript()` | string | 209 |
| `tracking.link` | `getTrackingLink()` | string | 214 |
| `tracking.enabled` | `isTrackingEnabled()` | `Integer.parseInt(v,"0")==1` — **`"1"`/`"0"`, not `"true"`/`"false"`** | 219 |
| `max.tracking.number.per.request` | `getMaxTrackingNumberPerRequest()` | `Integer.parseInt(v,"1")` | 181 |
| `post.manifest.script` | `getPostManifestScript()` | string, optional | 187 |
| `schedule.pickup.script` | `getSchedulePickupScript()` | string, optional | 192 |
| `schedule.pickup.configured` | `isSchedulePickupConfigured()` | `Boolean.parseBoolean(v)` — `"true"`/`"false"` | 197 |
| `is.shipping.aggregator` | `isShippingAggregator()` | `Integer.parseInt(v,"0")==1` — **`"1"`/`"0"`** | 201 |
| `shipping.payment.method` | `getShippingPaymentMethods()` | CSV string | 225 |
| `reverse.shipping.payment.methods` | `getReverseShippingPaymentMethods()` | CSV string, optional | 230 |
| `exchange.shipping.payment.methods` | `getExchangeShippingPaymentMethods()` | CSV string, optional | 235 |
| `available.serviceabilities` | `getAvailableServiceabilitiesCSV()` | CSV — production value has a typo, `GLOBAL_SERVICEABLITY` (not `-ILITY`); preserve the typo, don't "fix" it, or lookups against it will fail | 250 |
| `reserved.keywords.for.short.name` | `getReservedKeywordsForShortName()` | CSV string | 255 |
| `reverse.pickup.supported` | `isReversePickupSupported()` | `Boolean.parseBoolean(v,"false")` — **`"true"`/`"false"`** | 240 |
| `exchange.supported` | `isExchangeSupported()` | `Boolean.parseBoolean(v,"false")` — `"true"`/`"false"` | 245 |
| `reverse.pickup.provider.notification.script` | `getReversePickupProviderNotificationScript()` | string, optional | 260 |
| `forward.shipping.provider.notification.script` | `getForwardShippingProviderNotificationScript()` | string, optional | 265 |
| `pre.configuration.script.name` | `getPreConfigurationScriptNameScript()` | string, optional | 270 |
| `post.configuration.script.name` | `getPostConfigurationScriptName()` | string, optional | 275 |
| `days.to.track.courier.status.after.terminal.status` | `getDaysToTrackCourierStatusAfterTerminalStatus(default)` | int, optional | 280 |
| `shipping.provider.courier.update.script` | `getShippingProviderCourierUpdateScript()` | string, optional | 285 |
| `pii.masking.enabled.in.template` | `isPiiMaskingEnabledInTemplate()` | `Boolean.parseBoolean(v,"false")`, default false | 290 |
| `pii.masking.enabled.in.manifest.download` | `isPiiMaskingEnabledInManifestDownload()` | `Boolean.parseBoolean(v,"true")`, default true | 295 |
| `eligible.for.courier.prefetch` | `isEligibleForCourierPrefetch()` | `Boolean.parseBoolean(v,"false")`, default false | 300 |
| `carrier.pickup.time.allowed` | `isCarrierPickupTimeAllowed()` | `Boolean.parseBoolean(v,"false")`, default false | 305 |
| `preferred.courier.selection.script` | `getPreferredCourierSelectionScript()` | string, optional (aggregators) | 310 |

**Rule, not a suggestion**: pick the correct encoding *per property*, not "truthy". `is.shipping.aggregator`
and `tracking.enabled` use `"1"`/`"0"`; `reverse.pickup.supported` and `exchange.supported` use
`"true"`/`"false"`. There is no validation anywhere in the read code paths that catches a mismatched
encoding — it silently evaluates to the default (usually `false`), not an error.

One property named in earlier drafts of this analysis — `action.on.editing.shipment.after.courier.allocation`
— does **not** appear anywhere in `ShippingProviderSource.java`. It is not asserted here. If a future
ticket needs it, search `ShippingProviderMethod.java` or the RDBMS schema directly before assuming it
exists.

`schedule.pickup.script`, `schedule.pickup.configured`, `pre.configuration.script.name`,
`post.configuration.script.name` have real getters but are **not set by any of the five reference
sources** (`fedex.json`, `shiprocket.json`, `clickpost.json`, `bluedart.json`, `dtdc.json` — all
directly read). If a ticket requires these, there is no in-repo worked example to copy.

## `ShippingSourceConnector` fields

Confirmed directly from `ShippingSourceConnector.java`:

```java
private String  shippingSourceCode;
private String  name;
private String  displayName;
private String  helpText;
private int     priority;
private boolean requiredInAwbFetch;
private boolean requiredInTracking;
private boolean validateInAwbFetch;
private boolean thirdParty;
private String  verificationScriptName;
private Set<ShippingSourceConnectorParameter> shippingSourceConnectorParameters;
```

`thirdParty` exists on the entity but was not observed `true` on any connector in the five reference
sources examined — its runtime effect wasn't traced (out of scope of what was read this session; don't
assert what it does).

See `rules/connector-rules.md` for parameter types and the two structurally different patterns
(FedEx: two credential pairs in one connector; Bluedart: two separate connectors) reference sources use
for "split shipment-vs-tracking credentials."

## Naming inconsistency observed in the Mongo dumps

`fedex.json` line 91 and `clickpost.json` line 96 use `"sourceCode"` instead of `"shippingSourceCode"`
on one property entry each (everywhere else in the same files uses `"shippingSourceCode"`). The Java
field on `ShippingProviderSourceProperty` is `shippingSourceCode` — `"sourceCode"` is very likely a
copy-paste typo that MongoDB tolerates silently (no schema enforcement), not a documented alternate key.
New sources should use `shippingSourceCode` consistently and not treat `sourceCode` as a valid
alternative.
