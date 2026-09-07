# Uniware `shipment_tracking_status.code` allowlist (verified)

**Not the full production table.** These codes were confirmed present in git-tracked `build_*.sql`
migration files at the repository root (spot-checked directly this session: `HELD`,
`NOT_SERVICEABLE`, `DAMAGED`, `PARTIALLY_DELIVERED`, `CONTACT_CUSTOMER_CARE`, `DELAYED`,
`CIR_SHIPMENT_HELD`, `CIR_REACHED_AT_DESTINATION` each appear in multiple `build_*.sql` files) plus
two Java constants read directly:

```java
// UniwareCore/src/main/java/com/uniware/core/entity/ShipmentTrackingStatus.java:30-31
public static String MISSING_SHIPPING_PACKAGE_STATUS_FOR_UC_TRACKING_STATUS = "STATUS_NOT_DEFINED";
public static String MISSING_REVERSE_PICKUP_STATUS_FOR_UC_TRACKING_STATUS   = "CIR_STATUS_NOT_DEFINED";
```

These two constants are the fallback status codes `ShipmentTrackingServiceImpl` assigns when no
mapping resolves at all (confirmed used at `ShipmentTrackingServiceImpl.java:299,305,312`) — they
are always safe to treat as real, existing codes.

**If a mapping needs a code not listed below**: grep `shipment_tracking_status` inserts across
`build_*.sql`, or query the live `shipment_tracking_status` table. If still unknown, that is a
**blocking question** — do not invent a new `shipment_tracking_status` row for a courier-integration
ticket; that is a platform-level change outside a single integration's scope.

`stop_polling` lives on the status row itself, not on the mapping row — do not infer it from the
status name (a real ticket example: `LOST` may carry `stop_polling = 0`, meaning polling continues
despite the terminal-sounding name).

## Forward (`SHIP_TO_CUSTOMER`)

| Code | Where observed |
|---|---|
| `COURIER_ASSIGNED` | Real ticket (PI-8529) |
| `PICKUP_PENDING` | `db.sql`-style templates, `build_*.sql` |
| `PICKED_UP` | `build_*.sql` |
| `IN_TRANSIT` | `build_*.sql` |
| `OUT_FOR_DELIVERY` | `build_*.sql` |
| `UNDELIVERED` | `build_*.sql` |
| `DELIVERED_TO_CUSTOMER` | `build_*.sql` |
| `RTO_INITIATED` | `build_*.sql` |
| `RTO_IN_TRANSIT` | `build_*.sql` |
| `RTO_DELIVERED_TO_SELLER` | `build_*.sql`, referenced in domestic status tables |
| `REACHED_AT_DESTINATION` | Real ticket (PI-8529) |
| `HELD` | `build_*.sql` — verified present this session |
| `NOT_SERVICEABLE` | `build_*.sql` — verified present this session |
| `STATUS_NOT_DEFINED` | Java constant `ShipmentTrackingStatus.MISSING_SHIPPING_PACKAGE_STATUS_FOR_UC_TRACKING_STATUS` — verified |
| `CONTACT_CUSTOMER_CARE` | `build_*.sql` — verified present this session |
| `DELAYED` | `build_*.sql` — verified present this session |
| `LOST` | Real ticket (PI-8529); `build_*.sql` — verified present this session |
| `DAMAGED` | `build_*.sql` — verified present this session |
| `PARTIALLY_DELIVERED` | `build_*.sql` — verified present this session |
| `ORDER_CANCELLED` | Real ticket (PI-8529) |
| `CUSTOM_CLEARED` | Real ticket (PI-8529) |

## Reverse (`REVERSE_PICKUP`) — `CIR_*` prefix

| Code | Where observed |
|---|---|
| `CIR_PICKUP_PENDING` | `build_*.sql` |
| `CIR_PICKED_UP` | `build_*.sql` |
| `CIR_IN_TRANSIT` | `build_*.sql` |
| `CIR_OUT_FOR_DELIVERY` | `build_*.sql` |
| `CIR_UNDELIVERED` | `build_*.sql` |
| `CIR_DELIVERED_TO_SELLER` | `build_*.sql` |
| `CIR_STATUS_NOT_DEFINED` | Java constant `ShipmentTrackingStatus.MISSING_REVERSE_PICKUP_STATUS_FOR_UC_TRACKING_STATUS` — verified |
| `CIR_REACHED_AT_DESTINATION` | `build_*.sql` — verified present this session |
| `CIR_SHIPMENT_HELD` | `build_*.sql` — verified present this session |

## `type` values (mapping type, not a status code)

`SHIP_TO_CUSTOMER` | `REVERSE_PICKUP` | `RETURN_TO_ORIGIN` — confirmed directly against
`ShipmentTracking.java:31-35`'s `Type` enum (see `knowledge/entity-model.md` and
`rules/status-mapping-rules.md`).
