// Deterministic stub, structure confirmed against a real Shiprocket-International template
// (see rules/db-rules.md).
// Fill every {{PLACEHOLDER}}. Do not add real tenant lists or credentials here.

// 1. Register each new script as an empty shell — the real XML is a separate deliverable
//    (see templates/scraper-*.xml.tpl), not embedded in this insert.
db.uniwareScript.insertOne({
  _class: "com.uniware.core.vo.UniwareScriptVO",
  name: "{{TRACKING_NUMBER_ALLOCATION_SCRIPT_NAME}}",
  script: "",
  enabled: true,
  created: new ISODate(),
  updated: new ISODate(),
  version: "{{TICKET_ID}}",
  editableByCustomerSupport: false
});

db.uniwareScript.insertOne({
  _class: "com.uniware.core.vo.UniwareScriptVO",
  name: "{{SCRAPER_SCRIPT_NAME}}",
  script: "",
  enabled: true,
  created: new ISODate(),
  updated: new ISODate(),
  version: "{{TICKET_ID}}",
  editableByCustomerSupport: false
});

// Repeat the above insertOne block for every additional script the IntegrationSpec declares
// (verification script, post-manifest script, cancellation scripts) — one per script name.

// ------------------------------------------------------------------------------------------

// 2. Pin the ticket-specific version for whichever tenants are actually in scope.
//    Do NOT default to "all tenants" unless the ticket states a platform-wide rollout —
//    see rules/db-rules.md.
db.scriptVersion.insertOne({
  _class: "com.uniware.core.vo.ScriptVersionVO",
  tenantCode: "{{TENANT_CODE_OR_REMOVE_THIS_BLOCK_IF_NOT_TENANT_SCOPED}}",
  name: "{{TRACKING_NUMBER_ALLOCATION_SCRIPT_NAME}}",
  version: "{{TICKET_ID}}",
  created: new ISODate(),
  updated: new ISODate()
});

// ------------------------------------------------------------------------------------------

// 3. Only include this bulk block if the ticket explicitly requires platform-wide rollout.
//    Confirm the exclusion list matches current operational exclusions (e.g. non-production
//    tenant codes) — do not invent an exclusion list, ask if unsure.
//
// db.tenantProfile.find({ tenantCode: { $nin: ['{{EXCLUDED_TENANT_1}}'] } }).forEach(function (tenant) {
//   db.scriptVersion.insertMany([
//     {
//       "_class": "com.uniware.core.vo.ScriptVersionVO",
//       "tenantCode": tenant.tenantCode,
//       "name": "{{TRACKING_NUMBER_ALLOCATION_SCRIPT_NAME}}",
//       "version": "1.0",
//       "created": new ISODate(),
//       "updated": new ISODate()
//     }
//   ]);
// });
