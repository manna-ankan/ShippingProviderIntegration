# Runtime flow: allocate → label → manifest → tracking → cancellation

All method names and line numbers below were confirmed this session with a direct `grep -n` against
the real files (not carried over unverified from any earlier analysis):

```
ShippingProviderServiceImpl.java  — allocateShippingProvider:332, saveLabelInformationForShipment:722,
                                     saveMultiPartShippingPackages:1160, constructShipmentHandler:2133,
                                     generateTrackingNumber:2179, checkIfShippingProviderConnectorIsBroken:2214,
                                     scrapeShipmentStatuses:2268, cancelForwardCourier:2837
ShippingAdminServiceImpl.java     — addShippingProvider:1093, addOrUpdateShippingProviderConnector:1568,
                                     MASKED_PATTERN:200 (used at :1610)
DispatchServiceImpl.java          — scheduleManifestPickup:2560, closeShippingManifest:2644,
                                     executePostManifestScript:3224
```

## Handler dispatch

`ShippingProviderSource.getHandlerClassName()` (property `handler.class`) is a Java class name,
reflectively instantiated by `ShippingProviderServiceImpl.constructShipmentHandler` (`:2133`). All five
reference sources use the same value:

```
com.uniware.services.shipping.impl.ScrapedShipmentHandler
```

`ScrapedShipmentHandler` (full file read directly this session — 31 lines) extends
`AbstractShipmentHandler` and adds exactly one method:

```java
public Map<String, ProviderShipmentStatus> getShipmentStatuses(List<ShipmentTracking> shipments) {
    return getShippingProviderService().scrapeShipmentStatuses(getShippingProvider(), getTrackingNumbers(shipments));
}
```

No evidence anywhere in the five reference sources of a bespoke (non-scraped) handler class. Default to
`ScrapedShipmentHandler` unless a ticket explicitly requires custom Java — none of the references do.

## Lifecycle

```
Source config (Mongo)              ──▶ ShippingAdminServiceImpl: tenant provider + connector CRUD,
                                        live verification (addShippingProvider, addOrUpdateShippingProviderConnector)
        │
        ▼
Allocation / AWB generation        ──▶ ShippingProviderServiceImpl.allocateShippingProvider (:332)
                                        .generateTrackingNumber (:2179)
                                        ──▶ AbstractShipmentHandler.generateTrackingNumber dispatches on
                                            ShippingProviderMethod.TrackingNumberGeneration:
                                            LIST / GLOBAL_LIST / MANUAL / CUSTOM
                                            ──▶ CUSTOM ──▶ scrapeTrackingNumber ──▶ runs the script named
                                                by property tracking.number.allocation.script
        │
        ▼
Label persistence                  ──▶ ShippingProviderServiceImpl.saveLabelInformationForShipment (:722)
                                        .updateShippingLabelLink (two overloads, ~:1198 / ~:1419)
        │
        ▼
Multi-part shipment (MPS)          ──▶ ShippingProviderServiceImpl.saveMultiPartShippingPackages (:1160)
                                        — only fires if the script populated response.childTrackingNumbers.
                                        Confirmed directly: only Clickpost's generic script
                                        (Ref/Clickpost/TRACKING_NUMBER_ALLOCATION_GENERIC.xml, gated by
                                        connector param IS_MPS_ENABLED) populates this among the five refs.
        │
        ▼
Manifest / dispatch                ──▶ DispatchServiceImpl.createShippingManifest (~:417)
                                        .closeShippingManifest (:2644) ──▶ executePostManifestScript (:3224)
                                        [skipped entirely if post.manifest.script property is blank —
                                        confirmed Bluedart sets it to "" and Dtdc omits it altogether;
                                        both fall through to "not configured" identically]
                                        .scheduleManifestPickup (:2560) [gated by
                                        isSchedulePickupConfigured() — no worked example in any of the
                                        five reference sources]
        │
        ▼
Tracking / status sync             ──▶ ScrapedShipmentHandler.getShipmentStatuses ──▶
                                        ShippingProviderServiceImpl.scrapeShipmentStatuses (:2268) ──▶
                                        runs the script named by property scraper.script ──▶
                                        ScrapedShipmentStatusHandler SAX-parses the script's
                                        <Shipments><Shipment><TrackingNumber>/<Status>/<StatusDate></Shipment>
                                        output ──▶ ShipmentTrackingServiceImpl.doUpdateShipmentTracking
                                        (confirmed at ShipmentTrackingServiceImpl.java:161) ──▶
                                        DB-driven status mapping — see rules/status-mapping-rules.md
        │
        ▼
Cancellation                       ──▶ ShippingProviderServiceImpl.cancelForwardCourier (:2837)
                                        [returns true — a silent no-op success — if
                                        forward.shipping.provider.notification.script is unset. This is
                                        fails-open behavior: not validated at source-creation time, and
                                        the caller cannot distinguish "cancelled" from "no cancel
                                        mechanism configured" from the return value alone]
```

## Configuration cache staleness (operational, not a bug to design around)

`ShippingProviderSource` reads go through `ConfigurationManager`-backed caches
(`ShippingSourceConfiguration`, `ShippingConfiguration`), not raw Mongo/DB queries on every call. This
was directly confirmed while verifying `ShippingConfiguration.addShipmentTrackingStatus`
(`ShippingConfiguration.java:173-194`): when a `ShipmentTrackingStatusMapping` row references a
`shippingSourceCode` not yet in the in-memory cache, the code force-reloads
`ShippingSourceConfiguration` **once** (`ConfigurationManager.getInstance().markConfigurationDirty(...)`,
line 181) and retries; if the source is still not found after that single reload, it throws
`RuntimeException("Invalid Shipping Source code: ...")`.

**Consequence for a generated `db.js`/`db.sql`**: a newly-inserted `shippingSource` Mongo document is
not guaranteed visible to a running application server until the reload cycle runs. Inserting the
`shipment_tracking_status_mapping` SQL rows *before* the Mongo source document exists and is visible in
cache is the one ordering that reliably fails (hard `RuntimeException`, not a silent skip). Every
generated artifact set should be paired with a test-checklist step confirming the source is visible in
the admin UI's "add shipping provider" source dropdown before proceeding to status-mapping SQL — see
`rules/db-rules.md` for exact ordering.
