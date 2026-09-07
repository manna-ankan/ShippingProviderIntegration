# Uniware field expressions (verified against Java source)

Every entry below was checked directly against the actual entity class this session — file:line
citations included. This supersedes reliance on any provider script's or ticket's phrasing of these
expressions; where the ticket/Cursor's own catalog phrasing didn't match the real Java signature,
the discrepancy is called out explicitly (see "Corrections found" at the bottom — do not silently
carry over an unverified expression from a Jira sample into a generated script).

Do not invent an entity path not listed here. If a payload needs a field with no entry below and no
Jira/API-doc source, that's a **question**, not something to guess from a plausible-sounding name.

## Package / order

| Use | Expression | Verified at |
|---|---|---|
| Package code | `#shippingPackage.code` | `ShippingPackage.java:364` |
| Tracking number (already assigned) | `#shippingPackage.trackingNumber` | `ShippingPackage.java:495` |
| Provider code on package | `#shippingPackage.shippingProviderCode` | `ShippingPackage.java:513` |
| Additional info | `#shippingPackage.additionalInfo` | `ShippingPackage.java:531` |
| Box L/W/H (int, mm) | `#shippingPackage.boxLength` / `.boxWidth` / `.boxHeight` | `ShippingPackage.java:559,568,577` |
| Actual weight (**BigDecimal**, grams) | `#shippingPackage.actualWeight` | `ShippingPackage.java:595` |
| Facility | `#shippingPackage.facility` | `ShippingPackage.java:345` |
| Shipping address | `#shippingPackage.shippingAddress` (type `AddressDetail`, not a class literally named `ShippingAddress`) | `ShippingPackage.java:438` |
| Invoice | `#shippingPackage.invoice` | `ShippingPackage.java:704` |
| Sale order | `#shippingPackage.saleOrder` | `ShippingPackage.java:448` |
| Sale order items | `#shippingPackage.getSaleOrderItems()` | `ShippingPackage.java:832` |
| Internal sale order code | `#shippingPackage.saleOrder.code` | `SaleOrder.java:246` |
| Display order id | `#shippingPackage.saleOrder.displayOrderCode` | `SaleOrder.java:265` |
| Display order date (`Date`) | `#shippingPackage.saleOrder.displayOrderDateTime` | `SaleOrder.java:275` |
| Currency | `#shippingPackage.saleOrder.currencyCode` | `SaleOrder.java:470` |
| Payment method | `#shippingPackage.saleOrder.paymentMethod` | `SaleOrder.java:322` |
| COD flag | `#shippingPackage.saleOrder.cashOnDelivery` (boolean getter `isCashOnDelivery()`) | `SaleOrder.java:316` |
| **Store credit** (corrected — see below) | `#shippingPackage.saleOrder.totalStoreCredit` (**not** `.storeCredit`) | `SaleOrder.java:715` |

## Weight and dimension conversion — corrected

**`#shippingPackage.actualWeight` is a `BigDecimal`, not a `String`.** A Jira/API-doc sample that
writes `Double.parseDouble(shippingPackage.actualWeight)` (this exact phrasing appears in
`jira.md`'s PI-8529 field-mapping table for `phy_weight`, row 17) **will not compile** —
`Double.parseDouble` takes a `String` argument. The Jira's intent (grams → kg) is correct; the
literal expression it wrote is not. Use:

```
#{#shippingPackage.actualWeight.doubleValue() / 1000}
```

Same correction applies anywhere a ticket's sample expression calls `Double.parseDouble` or
`new BigDecimal(String)` on a field already confirmed to be typed `BigDecimal` in the entity —
check the entity, don't assume the ticket's Java-ish pseudocode is literally compilable.

| Conversion | Expression | Verified at |
|---|---|---|
| mm → cm, floor 1 (box dims are `int`) | `T(com.unifier.core.utils.NumberUtils).divide(new java.math.BigDecimal(#shippingPackage.boxLength), 10)` | `ShippingPackage.java:559` (int) + `NumberUtils` used identically in `Ref/Dtdc` before removal, pattern only, not independently re-verified this session |
| g → kg, package weight (`BigDecimal`) | `#shippingPackage.actualWeight.doubleValue() / 1000` | `ShippingPackage.java:595` |
| g → kg, item weight (`BigDecimal`) | `#invoiceItem.itemType.weight.doubleValue() / 1000` | `ItemType.java:259` |

## Invoice / invoice line

| Use | Expression | Verified at |
|---|---|---|
| Invoice code | `#shippingPackage.invoice.code` | `Invoice.java:161` |
| Invoice created date | `#shippingPackage.invoice.created` | `Invoice.java:199` |
| Invoice items | `#shippingPackage.invoice.invoiceItems` | `Invoice.java:229` |
| Invoice's facility | `#shippingPackage.invoice.facility` | `Invoice.java:132` |
| Item type | `#invoiceItem.itemType` | `InvoiceItem.java:109` |
| SKU code | `#invoiceItem.skuCode` | `InvoiceItem.java:155` |
| Quantity (`int`) | `#invoiceItem.quantity` | `InvoiceItem.java:196` |
| Unit price | `#invoiceItem.unitPrice` | `InvoiceItem.java:187` |
| Discount | `#invoiceItem.discount` | `InvoiceItem.java:223` |
| **Subtotal** | `#invoiceItem.subtotal` | `InvoiceItem.java:205` |
| Total | `#invoiceItem.total` | `InvoiceItem.java:277` |
| Shipping charges | `#invoiceItem.shippingCharges` | `InvoiceItem.java:232` |
| Shipping method charges | `#invoiceItem.shippingMethodCharges` | `InvoiceItem.java:241` |
| COD charges | `#invoiceItem.cashOnDeliveryCharges` | `InvoiceItem.java:250` |
| Gift wrap charges | `#invoiceItem.giftWrapCharges` | `InvoiceItem.java:259` |
| Prepaid amount | `#invoiceItem.prepaidAmount` | `InvoiceItem.java:268` |
| Item-level store credit | `#invoiceItem.storeCredit` | `InvoiceItem.java:304` |
| Total tax amount (direct) | `#invoiceItem.getTotalTaxAmount()` | `InvoiceItem.java:428` |
| Invoice item taxes (collection) | `#invoiceItem.invoiceItemTaxes` | `InvoiceItem.java:322` |
| Selling-price-scoped tax | `#invoiceItem.getSellingPriceInvoiceItemTax().getTotalTaxAmount()` | `InvoiceItem.java:419` — both `getTotalTaxAmount()` (all cost heads) and this selling-price-scoped variant exist; pick per the ticket's exact formula, they are not interchangeable |
| Item name | `#invoiceItem.itemType.name` | `ItemType.java:214` |
| HSN code | `#invoiceItem.itemType.hsnCode` | `ItemType.java:176` |
| Item weight | `#invoiceItem.itemType.weight` (`BigDecimal`) | `ItemType.java:259` |
| Country of origin | `#saleOrderItem.countryOfOrigin` | `SaleOrderItem.java:1194` |

## Shipping address (`AddressDetail`, not a class literally named `ShippingAddress`)

| Field | Expression | Verified at |
|---|---|---|
| Name | `#shippingPackage.shippingAddress.name` | `AddressDetail.java:152` |
| Address line 1 | `.addressLine1` | `:161` |
| Address line 2 | `.addressLine2` | `:170` |
| City | `.city` | `:179` |
| Country code (ISO) | `.countryCode` | `:197` |
| Pincode | `.pincode` | `:206` |
| Phone | `.phone` | `:215` |
| Email | `.email` | `:228` |
| State (returns `State` entity, not a string) | `.state` → `.state.code` for the code | `:260` |

**State full name**: the underlying capability exists —
`CacheManager.getInstance().getCache(LocationCache.class).getStateByCode(stateCode, countryCode).getName()`
is a real, used pattern (verified at `RegulatoryFormCache.java:62`, `PartyServiceImpl.java:129`).
**Not verified this session**: whether the scraper DSL exposes a bare `#locationCache` context
variable, or whether a script must reach it via the full `T(com.unifier.core.cache.CacheManager).getInstance().getCache(...)`
chain. Treat `#locationCache.getStateByCode(...)` as a plausible shorthand, not a confirmed script
binding — verify by testing before relying on it, or use the fully-qualified form to be safe:
```
T(com.unifier.core.cache.CacheManager).getInstance().getCache(T(com.uniware.services.cache.LocationCache).class).getStateByCode(#stateCode, #countryCode).getName()
```

## Facility

| Use | Expression | Verified at |
|---|---|---|
| Facility Alias (pickup/warehouse code) | `#shippingPackage.facility.getFacilityAlias(#shippingProviderCode, T(com.uniware.core.entity.FacilityAlias.SourceType).SHIPPING_PROVIDER)` | `Facility.java:271`, `FacilityAlias.java:27-29` (see `rules/script-rules.md` #8a) |
| Ship-from address by type | `#shippingPackage.invoice.facility.getPartyAddressByType(T(com.uniware.core.entity.PartyAddressType.Code).SHIPPING.name())` | `Facility extends Party` (`Facility.java:27`), `Party.java:376`, `PartyAddressType.java:30-34` — confirmed: `Facility` inherits `getPartyAddressByType(String)` from `Party` |

## Reverse pickup

| Use | Expression | Verified at |
|---|---|---|
| Reverse pickup code | `#reversePickup.code` | `ReversePickup.java:226` |
| Reverse pickup's sale order | `#reversePickup.saleOrder` | `ReversePickup.java:207` |

Context: allocation scripts are injected either `shippingPackage` (forward) or `packageDO`
(`ReversePickup`, reverse) — branch on `shippingMethodName` (pattern only, not independently
re-verified against the exact string comparison this session; check the specific ticket/method
config before assuming `'ReversePickup-Prepaid'` is the universal comparison value).

## Config / connector access from inside a script

| Use | Expression |
|---|---|
| Connector or config param value | `#shippingProviderParameters.get('paramName')` |
| Source-level static property | re-resolve via `ConfigurationManager`, then `.getPropertyValue('key')` — confirmed exact pattern at `Ref/Dtdc/dtdcCustomScraperScript.xml:103` before `Ref/` was removed from this checkout; see `knowledge/script-engine.md` |

SpEL stored as a connector/config param default (e.g. a reference-number expression) is a literal
string like `#{#shippingPackage.saleOrder.displayOrderCode}` — the `#{...}` wrapper is part of the
stored string itself, not evaluated until the platform compiles it at runtime.

## Utility classes (confirmed used in scripts this session, before `Ref/` removal)

`T(com.unifier.core.utils.JsonUtils)`, `StringUtils`, `DateUtils`, `NumberUtils`,
`T(com.unifier.core.utils.EncryptionUtils)` (confirmed: `base64DecodeToFile`, used in FedEx's label
handling). `PdfUtils`, `CustomFieldUtils`, `EntitySourceReferenceUtils`, `UserContext` are named in
Cursor's catalog as utilities used in `Ref/` scripts — **not independently re-verified this
session** (no script using them was read directly); list them as plausible, not confirmed, until
checked against an actual script or the class itself.

## Corrections found this session (do not repeat these)

1. **`shippingPackage.actualWeight` is `BigDecimal`, not `String`** — `Double.parseDouble(...)` on
   it is a type error, despite `jira.md`'s PI-8529 field table writing it that way. Use
   `.doubleValue()`.
2. **`SaleOrder` has no `storeCredit` getter** — the real field is `totalStoreCredit`
   (`getTotalStoreCredit()`, `SaleOrder.java:715`). A ticket or catalog saying
   `saleOrder.storeCredit` is referencing a property that doesn't exist on the entity.
3. Both corrections above were present, uncaught, in this skill's own previously-generated
   `TRACKING_NUMBER_ALLOCATION_ITHINKINTL.xml` (the version generated one session ago, before this
   catalog existed) — fixed in the regression-test regeneration, see `FINAL-SKILL-REGRESSION.md`.
