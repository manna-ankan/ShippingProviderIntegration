-- Deterministic stub, structure confirmed against a real Shiprocket-International template
-- (see rules/db-rules.md and rules/status-mapping-rules.md).
--
-- ORDERING: apply the corresponding source.json (Mongo) insert FIRST and confirm the source
-- is visible in the admin UI's "add shipping provider" dropdown before running this — see
-- knowledge/runtime-flow.md. Running this first against a source not yet in cache will
-- throw RuntimeException("Invalid Shipping Source code: ...") after one retry.
--
-- Only generate the SHIP_TO_CUSTOMER block below unconditionally. Only generate the
-- REVERSE_PICKUP block if the source's reverse.pickup.supported property is "true" — see
-- rules/status-mapping-rules.md rule 3 and rules/source-rules.md #8.

INSERT IGNORE INTO shipment_tracking_status_mapping
  (provider_status, shipment_tracking_status_id, shipping_source_code, type, provider_description) VALUES
("{{PROVIDER_RAW_STATUS_1}}", (SELECT id FROM shipment_tracking_status WHERE code = "{{UC_STATUS_CODE_1}}"), "{{PROVIDER_CODE}}", "SHIP_TO_CUSTOMER", "{{optionalHumanDescription}}"),
("{{PROVIDER_RAW_STATUS_2}}", (SELECT id FROM shipment_tracking_status WHERE code = "{{UC_STATUS_CODE_2}}"), "{{PROVIDER_CODE}}", "SHIP_TO_CUSTOMER", "");
-- Repeat one row per confirmed provider-status → Uniware-status mapping. Every UC_STATUS_CODE
-- must be an EXISTING shipment_tracking_status.code — never invent a new one here
-- (status-mapping-rules.md rule 4). A subselect by code, never a literal numeric id.

-- REVERSE_PICKUP block — include only if this source supports reverse pickup:
-- INSERT IGNORE INTO shipment_tracking_status_mapping
--   (provider_status, shipment_tracking_status_id, shipping_source_code, type, provider_description) VALUES
-- ("{{PROVIDER_RAW_REVERSE_STATUS_1}}", (SELECT id FROM shipment_tracking_status WHERE code = "{{UC_REVERSE_STATUS_CODE_1}}"), "{{PROVIDER_CODE}}", "REVERSE_PICKUP", "");
