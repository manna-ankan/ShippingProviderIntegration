# Integration Validation Report — template

Fill this after Phase B generation, checking every item against `rules/validation-rules.md`.

```
Provider: <NAME> (<CODE>)
Status: READY | NEEDS_REVIEW | BLOCKED

Generated artifacts:
[ ] source.json
[ ] <TRACKING_NUMBER_ALLOCATION_SCRIPT_NAME>.xml
[ ] <SCRAPER_SCRIPT_NAME>.xml
[ ] <VERIFICATION_SCRIPT_NAME>.xml
[ ] db.sql
[ ] db.js

Structural validation:
[ ] Valid JSON/SQL/XML syntax
[ ] No _id field in source.json
[ ] Every boolean property encoding matches knowledge/entity-model.md's table
[ ] Every PersistentParam name a script emits is declared as a connector parameter
[ ] Every connector declares a non-blank verificationScriptName

Uniware validation:
[ ] handler.class is ScrapedShipmentHandler (or justified otherwise)
[ ] No REVERSE_PICKUP artifacts generated if reverse.pickup.supported is false/unset
[ ] No in-script status-translation logic — <Status> carries the raw provider value only
[ ] Every <Status> value the tracking script can emit has a shipment_tracking_status_mapping row,
    or the gap is listed under Assumptions/Questions below

DB validation:
[ ] shipment_tracking_status_mapping uses INSERT IGNORE + subselect by status code
[ ] No duplicate (provider_status, shipping_source_code, type) rows within the same insert
[ ] Ordering note present: Mongo source insert before status-mapping SQL

Semantic validation (Jira vs IntegrationSpec vs generated artifacts):
[ ] Every capability requested in the ticket has a corresponding script/property, or is explicitly
    listed as unsupported with a reason
[ ] Every field the ticket/API docs mark mandatory is populated in the allocation request payload
[ ] Any Jira-vs-source-of-truth conflict is listed under Conflicts below, not silently resolved

Secrets check:
[ ] No credential, token, password, or proxy secret appears literally in any generated file
[ ] All example/placeholder values use <ANGLE_BRACKET> tokens, never a value copied from a real
    reference script or a real Jira sample payload

Warnings:
- <list anything non-blocking but worth a developer's attention>

Assumptions:
- <list, each traceable to a [JIRA]/[API-DOC]/[UNIWARE-CODE]/[REFERENCE-INTEGRATION]/[RULE] source tag>

Conflicts:
- <list any place Jira and confirmed Uniware behavior disagree — see status-mapping-rules.md for the
  one documented, always-check-for-this-shape example>

Developer confirmation required:
1. <question>
2. <question>

Confidence: <0-100>%
```

## Test checklist (hand to the developer alongside this report)

1. Confirm the new source appears in the admin UI's "add shipping provider" source dropdown (cache
   visibility — see `knowledge/runtime-flow.md`).
2. Create a tenant `ShippingProvider` against the new source; save connector credentials and confirm
   live verification succeeds (this is the only path that persists credentials at all — see
   `rules/connector-rules.md`).
3. Book a dummy/sandbox shipment; confirm the AWB is returned and stored.
4. Confirm the label file lands where expected and is retrievable (not just referenced).
5. Poll tracking at least once; confirm a `<Status>` value comes back and either maps correctly via
   `shipment_tracking_status_mapping` or is caught by this report's "every `<Status>` value has a
   mapping row" check before this step.
6. If reverse pickup is in scope: repeat 3-5 for the reverse flow.
7. If cancellation is in scope: trigger it and confirm the provider actually receives the cancellation
   call, not just a silent success (see the fails-open behavior noted in `knowledge/runtime-flow.md`
   for sources with no cancellation script configured).
