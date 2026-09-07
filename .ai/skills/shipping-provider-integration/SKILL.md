---
name: shipping-provider-integration
description: >-
  Canonical, tool-agnostic skill for implementing a new Uniware Shipping Provider (courier)
  integration from a Jira ticket plus provider API documentation, verified against the real
  Uniware Java source. Two-phase: Phase A analyzes and produces an IntegrationSpec + questions,
  then stops for human approval; Phase B generates source.json, scraper scripts, db.sql, db.js,
  and a validation report only after that approval. Works with or without a developer-supplied
  reference integration package. This file is self-contained — it does not rely on any AI tool's
  native skill-discovery mechanism. A human must explicitly point an agent at this file.
---

# Shipping Provider Integration — canonical skill

**If you are an AI agent and a human has just told you something like "use
`.ai/skills/shipping-provider-integration/` for this task" or "read
`.ai/skills/shipping-provider-integration/SKILL.md` and follow it" — this is the correct file. Read
it completely, in order, right now, before doing anything else.** Do not assume you already know
this workflow from training data or a similar-sounding task. Do not skip to generating code.

This skill is not specific to any AI coding tool. It does not rely on Claude Code's, Cursor's,
Kiro's, Antigravity's, or any other tool's automatic skill-discovery. It is invoked **explicitly**,
by a human telling an agent to read this file. Everything the agent needs is either in this file or
in a file this file points to by a repository-relative path — never an absolute, machine-specific
path.

If you are a human developer, not an AI agent: read `README.md` in this same directory instead —
it explains how to *use* this skill, with copy-paste prompts. This file (`SKILL.md`) is the
instruction set the AI agent itself follows once you've pointed it here.

## Act as

A senior Uniware integration engineer. Never invent Uniware behavior. Never silently guess. When
uncertain, ask — see "Source of truth" below. This is not a free-form code generator — see "Design
principle" at the end of this file.

## Step 0 — Resolve paths, then run the prerequisite check

Every path in this skill and its supporting files is repository-relative. Resolve the repository
root first (e.g. `git rev-parse --show-toplevel`, or however your environment identifies the
current repository root), then treat every path below as relative to that root. Never hardcode or
assume a specific developer's absolute filesystem path.

Then read `prerequisite-check.md` in this directory and follow it exactly. It defines two tiers:

- **Tier 1 (Uniware Java source) is a hard requirement.** If a required source file is missing,
  stop and report it as a prerequisite failure — do not proceed on assumptions about what the
  source would have contained.
- **Tier 2 (a reference integration package) is optional and developer-supplied only.** Never
  discover or search for reference integrations automatically. If the developer explicitly provides
  a reference path in their prompt for this run, resolve it and use it as pattern material (never
  copy verbatim, never copy secrets out of it). If the developer provides no reference path,
  **skip reference integrations entirely, say so explicitly in the analysis output**, and proceed
  using only the Uniware source plus the knowledge bundled in this skill (`knowledge/`, `rules/`,
  `templates/`, `schemas/`). Never write or imply that a reference provider was read when it was
  not actually provided and inspected during this run.

## Source of truth

Five explicit tiers, in priority order:

1. **Actual Uniware Java/source contracts** — tag `[UNIWARE-CODE]`. Ground truth for what the
   platform actually does. A claim here must trace to a real file:line, not a class-name guess.
2. **Explicit Jira / ticket requirements** — tag `[JIRA]`. Ground truth for what *this* integration
   must do, business-wise. Ticket-specific and takes priority over generic bundled knowledge
   (tier 4) — a ticket's explicit instruction should not be silently overridden just because it
   differs from how other integrations happen to work.
3. **API / provider documentation supplied for this ticket** — tag `[API-DOC]`. Ground truth for
   the external contract this integration must call.
4. **Verified shared skill knowledge** (`knowledge/`, `rules/`) — tag `[RULE]`. Patterns and facts
   already checked against tier 1, with citations. Useful for speed and consistency, but every
   entry should itself be traceable back to tier 1 — treat an uncited claim even in this skill's
   own files with the same suspicion as an uncited claim anywhere else.
5. **Sanitized examples/templates** (`examples/`, `templates/`) — illustrative structure only.
   **Examples must never override tier 1/2/3 evidence.**

A developer-supplied reference integration package, if explicitly provided for this run, is **not a
numbered tier** — optional supplementary evidence that, if actually read this run, can inform
tier 4's confidence but is never authoritative on its own and is never required.

Tag every non-trivial claim with its source tag. If tier 2 (Jira) conflicts with tier 1 (confirmed
Uniware behavior), **do not silently prefer either tier**:

1. Identify the conflict.
2. Document it with: the Jira requirement, the actual Uniware behavior, the impact of each choice,
   a recommended option, and the alternative option.
3. Record it in `IntegrationSpec.conflicts[]`.
4. Set `generationGate: "NEEDS_REVIEW"`.
5. Require explicit developer approval, choosing one option, before generating the affected
   artifact.

Neither "Jira wins because it's specific to this ticket" nor "Java wins because it's ground truth"
is a default — a human decides, every time this shape of conflict appears. The status-mapping
mechanism is the standing worked example — see `rules/status-mapping-rules.md`'s mandatory
dual-option gate.

Missing information gets one of three labels, never a guess: `Missing`, `Assumption`, `Requires
Developer Confirmation`.

## Non-negotiable behaviors

1. Never silently resolve a Jira-vs-Uniware conflict in either direction.
2. When such a conflict exists: identify it, explain both interpretations, mark
   `generationGate: NEEDS_REVIEW`, and require explicit approval before generating the affected
   artifact.
3. Never invent an API or authentication mechanism not documented in the ticket/API docs supplied
   this run.
4. Never copy a sibling provider's authentication pattern onto a new provider just because it's the
   "closest" reference — a reference is a structural comparison point, not a template to force-fit.
   See `templates/scraper-verify.xml.tpl`'s three explicit auth OPTIONS.
5. Never copy secrets, tokens, or credentials from reference material, Jira samples, or API-doc
   samples into any generated artifact, example, or this skill's own knowledge files.
6. Never discover or search for reference integrations automatically. Use references only when
   the developer explicitly provides a reference path for this run.
7. Never claim a provider reference was consulted when it was unavailable or not actually read this
   run — this applies even if the provider's general shape is "known" from training data; if the
   file wasn't opened this run, say so.
8. Use actual Uniware Java contracts as the primary source for platform behavior (tier 1).
9. Use Jira as the primary source for ticket-specific requirements (tier 2) — do not substitute
   this skill's generic patterns (tier 4) for what the ticket actually asks, except where tier 1
   confirms the ticket's ask is architecturally wrong, in which case see rule 1/2.
10. Generated scripts must be derived from the **approved** `IntegrationSpec`, never blindly filled
    from a provider template — a template provides XML structure and tag vocabulary, not
    provider-specific behavior.

## Read before any work

Required, in this order: `prerequisite-check.md`, `knowledge/entity-model.md`,
`knowledge/runtime-flow.md`, `schemas/integration-spec.schema.json`.

Then as needed per the ticket's scope: `knowledge/script-engine.md`,
`knowledge/catalogs/uniware-field-expressions.md` (do not invent a `#shippingPackage...`-style
expression not listed there and not directly given by the ticket),
`knowledge/catalogs/uc-tracking-statuses.md`, and the relevant `rules/*.md` files. Do not infer
behavior from class or method names alone — verify against the real source when a claim isn't
already covered by `knowledge/*.md`'s citations.

## Two phases — the safety gate

### Phase A — Analysis only (default; this is what runs unless a human has already approved a spec)

Given a Jira ticket and/or provider API documentation, produce:

- Understanding of the Jira ticket
- Provider API analysis
- Uniware architecture analysis (which entities, services, handler this integration touches)
- Required source properties
- Connector requirements (credentials, verification)
- Authentication mechanism (derived from the actual API contract — see "Authentication has no
  default" below)
- Allocation (AWB creation) flow
- Label flow
- Tracking flow
- Cancellation flow (if in scope)
- Verification flow
- Status mapping design
- DB requirements
- Scraper script requirements
- Assumptions
- Unknowns / open questions
- Risks
- An `IntegrationSpec` conforming to `schemas/integration-spec.schema.json`
- An `ANALYSIS.md` report (see `examples/analysis-report.example.md` for the shape)
- A confidence score
- A `generationGate` value

Steps:

1. Parse capabilities, authentication shape, required APIs, and status codes. If a required API has
   no sample request/response, that is a **blocking question**, not something to infer from the
   docs' prose alone.
2. If the developer explicitly provided a reference path and it is available: identify the closest
   reference integration by comparing auth pattern, capability set, and aggregator-vs-direct-courier
   shape. State the reason and what will **not** be copied from it. If the provider's real auth/API
   shape doesn't match any catalogued pattern, say so — set `authentication.pattern: "other"`
   rather than force-fitting it. If no reference path was provided, skip this step entirely and
   say so in the analysis.
3. Produce the `IntegrationSpec` and `ANALYSIS.md`.
4. **Stop.** List every blocking question. Do not write `source.json`, scraper XML, `db.sql`, or
   `db.js` in this phase, regardless of how confident the analysis feels.

`generationGate` must be `BLOCKED`, `NEEDS_REVIEW`, or `READY`. Only `READY` — no unresolved
blocking questions — permits moving to Phase B, and only after a human has actually reviewed and
approved the spec. A high confidence score does not substitute for approval. **Analyzing a ticket is
never, by itself, permission to generate production artifacts** — a human must say so explicitly,
even if their original request sounded like "build the integration."

### Phase B — Generation (only after explicit human approval of the Phase A spec)

1. Fill `templates/source.json.tpl`, `templates/db.sql.tpl`, `templates/db.js.tpl`
   deterministically from the approved spec — this is template-filling, not free generation.
2. Scripts: start from `templates/scraper-verify.xml.tpl`, `templates/scraper-allocate.xml.tpl`,
   `templates/scraper-track.xml.tpl`; adapt placeholders per the spec's `authentication` and
   `fieldMappings`. Follow `rules/script-rules.md` for the auth pattern, output contracts, and
   label-acquisition pattern chosen in the spec.
3. SQL: only HIGH-confidence (and human-approved MEDIUM-confidence) status mappings. Omit LOW.
   Uniware status codes must be real existing `shipment_tracking_status.code` values — never
   invented. Forward-only providers get no `REVERSE_PICKUP` rows.
4. Produce a validation report from `validation/validation-report.template.md`, checked against
   `rules/validation-rules.md`, plus a test checklist.
5. **Write generated artifacts to an output directory the developer specifies (or a clearly
   separate, obviously-non-production location if none is specified) — never applied to a live
   database.** This phase produces files for a human to review, execute, and test — it never runs
   SQL, never touches Mongo/MySQL, and never edits Uniware Java.

## Hard contracts (do not deviate without an explicit, stated reason)

- Allocation script: accumulate in `resultItems`, then `<text>` for the tracking number and
  explicit `#response.put(...)` for `shippingLabelLink` / `shippingCourier` / any other value
  `AbstractShipmentHandler` reads. See `rules/script-rules.md` #5.
- Tracking script:
  `<Shipments><Shipment><TrackingNumber>/<StatusDate dd-MMM-yyyy HH:mm:ss>/<Status raw-provider-value></Shipment></Shipments>`.
  `<Status>` is never translated in-script **unless** the mandatory dual-option gate in
  `rules/status-mapping-rules.md` was explicitly resolved in favor of in-script translation.
- Connector parameter types: `TEXT`, `PASSWORD`, `HIDDEN`, `CHECKBOX`, `READONLY`, `LAST_3_CHARS`
  (authoritative: `ShippingSourceConnectorParameter.Type`) — **no `SELECT`** on connectors;
  dropdowns belong on `shippingSourceConfigParameters` (its own 5-value `Type` enum — see
  `rules/connector-rules.md`).
- Handler: default `com.uniware.services.shipping.impl.ScrapedShipmentHandler`.
- Property keys: only from the table in `knowledge/entity-model.md`, or explicitly marked
  `scriptOnly` with a stated reason.
- Boolean property encoding is per-property — check the table, don't assume uniformity.
- **Authentication has no default.** OAuth2, JWT, and Bearer-token schemes are three of several
  precedented patterns (see `knowledge/script-engine.md`'s catalogue and
  `templates/scraper-verify.xml.tpl`'s three OPTIONS) — none of them is a fallback for a provider
  whose real auth contract isn't yet nailed down. If the ticket/API docs don't describe a
  token/login/refresh mechanism, the correct answer is static credentials with no refresh logic,
  not an invented OAuth flow.

## Security

Mask every secret. Use `<ANGLE_BRACKET>` placeholders in every generated artifact and every
example. Never copy a live token/credential from a Jira sample, an API doc sample, or an existing
reference script into a generated artifact — describe the *pattern*, never the value. This applies
equally to test/fake credentials: even placeholders should read unambiguously as placeholders.

## Output sequence

Phase A: `1. Understanding → 2. Uniware Mapping → 3. Reference Selection (or "no reference provided") →
4. IntegrationSpec → 5. Risk/Ambiguity`. Phase B (after approval): generated artifacts + validation
report + test checklist.

## Design principle (do not violate)

```
AI            = reasoning, extraction, mapping, analysis
Rules/Schemas = deterministic structure
Templates     = deterministic stubs
Validator     = correctness checks
Human         = final approval and testing
```

Not a free-form code generator. If a step can be done by filling a template deterministically from
the spec, do that instead of generating prose-to-code freely.

## Supporting files in this skill

```
.ai/skills/shipping-provider-integration/
├── SKILL.md                       — this file
├── README.md                      — human usage guide (read this if you're a developer, not an agent)
├── PORTABILITY.md                 — prerequisite tiers, git-sharing strategy
├── prerequisite-check.md          — exact tier-1/tier-2 check procedure, exact error text
├── knowledge/
│   ├── entity-model.md            — Mongo template vs RDBMS tenant-instance layers
│   ├── runtime-flow.md            — allocate → label → manifest → tracking → cancellation
│   ├── script-engine.md           — scraper-script DSL: envelope, HTTP calls, auth patterns
│   └── catalogs/
│       ├── uniware-field-expressions.md   — verified entity-path expressions
│       └── uc-tracking-statuses.md        — verified Uniware status-code allowlist
├── rules/
│   ├── source-rules.md
│   ├── connector-rules.md
│   ├── status-mapping-rules.md    — the mandatory dual-option conflict gate
│   ├── db-rules.md
│   ├── script-rules.md
│   └── validation-rules.md
├── schemas/
│   └── integration-spec.schema.json
├── templates/                     — placeholder-only deterministic stubs, never real values
├── examples/
│   └── analysis-report.example.md
└── validation/
    └── validation-report.template.md
```
