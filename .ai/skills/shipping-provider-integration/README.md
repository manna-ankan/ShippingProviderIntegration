# Shipping Provider Integration Skill — Developer Guide

A canonical, **tool-agnostic** knowledge and workflow package for implementing new Uniware Shipping
Provider (courier) integrations. Works the same way with Claude, Cursor, Kiro, Antigravity, or any
other AI coding agent — because it isn't wired into any of their native skill systems. You invoke it
by **telling your AI agent to read it**, explicitly, every time.

You do not need to understand how this skill is built internally to use it. This document is the
only thing you need to read.

---

## QUICK START

Copy-paste this into your AI coding agent's chat, in the Uniware repository, after you have a Jira
ticket and provider API documentation ready:

```
Use the canonical Shipping Provider Integration skill:

.ai/skills/shipping-provider-integration/SKILL.md

Read the skill and its supporting knowledge/rules/templates before doing anything else.

I will provide:
1. Jira ticket (pasted below, or attached)
2. Provider API documentation (pasted below, or attached)
3. (Optional) Reference integration path

Analyze the integration using PHASE A only.

Do not generate production artifacts yet.

After the analysis, stop and wait for my approval.

--- JIRA ---
<paste your Jira ticket text here>

--- API DOCUMENTATION ---
<paste or describe the provider's API documentation here>

--- REFERENCE INTEGRATIONS (optional, omit if none) ---
Reference path: ./my-provider-references/
```

Once you've reviewed Phase A's output and are ready to generate files, reply with this:

```
Phase A is approved.

Proceed to PHASE B for this integration.

Generate the artifacts into: <the output directory you want, e.g. shipping-provider-integrations/<PROVIDER_CODE>/>

Do not apply any database changes. Do not run any script. Do not modify Uniware Java.
```

That's it for the common case. Everything below is detail for when you need it.

---

## 1. What is this skill?

A packaged, verified body of knowledge about how Uniware's Shipping Provider integration
architecture actually works (entities, services, the scraper-script DSL, connector/credential
handling, status mapping), plus a two-phase workflow (analyze, then — only after your approval —
generate) that an AI coding agent follows to help you build a new courier integration. It is not a
tool plugin. It is a folder of Markdown/JSON/XML-template files that any AI agent can read when you
point it there.

## 2. When should I use it?

Whenever you're implementing a new Shipping Provider (courier) integration for Uniware — a new
`shippingSource`, its connector/credentials, its allocation/tracking/verification scripts, its
status mapping, and its DB setup scripts. Also useful if you're extending an existing provider with
new capabilities (e.g. adding an international variant of a domestic integration), since the same
architecture knowledge applies.

## 3. What inputs do I need?

Two required, one optional:

1. **The Jira ticket** (or equivalent task description) for the integration — the business
   requirements: what capabilities are needed (booking, label, tracking, cancellation), what fields
   the provider requires, any known quirks the ticket already documents.
2. **The provider's API documentation** — endpoints, request/response shapes, authentication,
   status codes. Sample request/response payloads are extremely valuable; without them, the agent
   will correctly treat that API as a blocking question rather than guessing its shape.
3. **(Optional) A reference integration path** — if you have sanitized reference integrations
   available locally (e.g. `./reference/` or `./shipping-ref/`), you can provide the path
   explicitly and the skill will use them as pattern material. If omitted, the skill proceeds
   without any reference integrations and does not search for them.

## 4. Where should I put/provide the Jira?

You don't need to put it anywhere in the repository. Paste the ticket text directly into your
prompt to the agent (see Quick Start above), or attach it as a file if your tool supports
attachments. If you'd rather keep it as a file for reuse, any path is fine — just tell the agent
where it is (e.g. "read the Jira from `notes/PI-1234.md`"). The skill does not require or expect a
Jira file at any specific location.

## 5. Where should I provide API documentation?

Same as the Jira — paste it, attach it, or point the agent at a file/URL you control. If the
documentation is a webpage, paste the relevant sections (auth, each endpoint, sample
request/response, status codes) rather than just a link, since the agent may not be able to fetch
it live.

## 6. What additional information may be required?

Depending on the ticket, the agent may come back with specific questions before or during Phase A
(this is expected behavior, not a failure) — commonly:

- Sample request/response for every API endpoint in scope (booking, label, tracking, cancellation).
- The provider's full status-code list with business meaning for each.
- Whether reverse pickup / RTO / cancellation is in scope.
- Which tenants this rollout applies to (a pilot, or platform-wide).
- Clarification when the ticket's instructions conflict with how Uniware actually works (see
  question 16 below — this is a designed behavior, not a bug).

## 7. What exact prompt should I give to an AI agent?

See **QUICK START** above — copy it verbatim, filling in your Jira and API docs. The key sentence
that matters most, if you're writing your own prompt instead: *"Read `.ai/skills/shipping-provider-integration/SKILL.md`
and follow it. Do Phase A only. Stop before generating production artifacts."*

## 8. What should I expect from Phase A?

An `IntegrationSpec` (a structured JSON document) and an `ANALYSIS.md` report covering:
understanding of the Jira, provider API analysis, Uniware architecture mapping, required source
properties, connector/credential requirements, the authentication mechanism, the allocation/label/
tracking/cancellation/verification flows, the status-mapping design, DB requirements, assumptions,
open questions, risks, a confidence score, and a `generationGate` value (`BLOCKED`, `NEEDS_REVIEW`,
or `READY`). **No production files are generated in this phase** — no `source.json`, no scripts, no
SQL, no `db.js`. See `examples/analysis-report.example.md` in this skill for the exact shape.

## 9. When should I approve Phase A?

After you've read the `IntegrationSpec`/`ANALYSIS.md` and are satisfied that:

- The capabilities, field mappings, and auth mechanism match what you know about the provider.
- Every open question is either answered (by you, in your reply) or acceptable to leave as a
  documented assumption.
- Any flagged Jira-vs-Uniware conflict (see question 16) has been resolved by your explicit choice,
  not left ambiguous.

You do not need `generationGate: READY` to approve — you can approve with `NEEDS_REVIEW` open items
as long as you've explicitly addressed them in your approval message (e.g. "approved, and for the
status-mapping conflict, go with Option B").

## 10. What happens in Phase B?

The agent fills deterministic templates (not free-form generation) from your approved
`IntegrationSpec`: the `shippingSource` document, the connector/credential definitions, the
scraper scripts (allocation, tracking, verification, and cancellation if in scope), the
`shipment_tracking_status_mapping` SQL, and the `db.js` script-registration inserts. It then
produces a validation report and a manual test checklist.

## 11. What files will be generated?

Typically: `source.json` (the Mongo `shippingSource` document, mongo-shell-insert style),
`db.sql` (status-mapping SQL), `db.js` (script + scriptVersion registration), one or more scraper
XML scripts (allocation, tracking, verification, and cancellation if in scope), a `VALIDATION.md`
report, and a `TEST_CHECKLIST.md`. Exact filenames follow your ticket's naming convention.

## 12. Where will generated files be written?

**Wherever you tell the agent to write them** — an output directory you specify in your Phase B
approval message. This skill never writes into itself, never writes production files without an
explicit output location, and never applies anything to a live database or Mongo/MySQL instance
directly. If you don't specify a directory, expect the agent to ask, or to use an obviously
non-production scratch location and tell you where.

## 13. What should I manually verify?

Before treating any generated artifact as final:

- Every field mapping against the actual provider API documentation, especially date formats, unit
  conversions (weight/dimensions), and anything the ticket flags as a "live behavior" that differs
  from the provider's written docs.
- The authentication script against a real (sandbox) credential — the agent may correctly identify
  the auth *pattern* but the exact request/response field names should be checked live.
- The `db.sql` status mappings against your platform's actual `shipment_tracking_status` table.
- That no `NEEDS_REVIEW` item was silently dropped — check `VALIDATION.md`'s "Developer Confirmation
  Required" section.
- Run everything in `TEST_CHECKLIST.md` against a real sandbox before going live.

## 14. What should I NEVER give the AI?

- **Real production credentials, tokens, API keys, or passwords** — for the provider, or for
  Uniware itself. Use sandbox/test credentials only, and even those should be treated as sensitive.
- Real customer/PII data in sample payloads — sanitize sample request/response bodies first.
- Direct database or production system access/execution — this skill's design explicitly never
  applies SQL or Mongo inserts itself; do not ask the agent to do so either.
- Access to unrelated production systems "just in case" — scope what you share to what the
  integration actually needs.

## 15. What should I do when API documentation is incomplete?

Expect (and welcome) the agent flagging this as a blocking question rather than guessing. Your
options: get the missing detail from the provider (a sample request/response, a status-code list,
an auth flow description), or explicitly tell the agent to proceed with a stated assumption — in
which case it should be recorded as an `Assumption`, not silently treated as fact. Do not tell the
agent to "just guess" the shape of an undocumented API — that's exactly the failure mode this skill
is designed to avoid.

## 16. What should I do when the AI says NEEDS_REVIEW?

Read why. Two common cases:

- **A genuine open question** (missing sample, ambiguous field, unconfirmed assumption) — answer it,
  or explicitly accept the stated assumption.
- **A Jira-vs-Uniware architecture conflict** (the most important case this skill is designed to
  catch) — the ticket asks for something that conflicts with how Uniware's platform actually works.
  The agent will present both the literal ticket requirement and the standard Uniware behavior, with
  an impact assessment and a recommended option. **You choose.** Reply with your choice explicitly
  (e.g. "go with the standard Uniware behavior" or "follow the ticket literally, we've confirmed
  that's intentional") before Phase B proceeds on that specific artifact.

Never let `NEEDS_REVIEW` items pass through to Phase B unaddressed just to keep momentum — that is
the exact failure mode this workflow exists to prevent.

## 17. What should I do when references are missing?

Nothing — this is expected and the default behavior. If you don't provide a reference integration
path, the agent proceeds using the actual Uniware Java source plus this skill's bundled knowledge,
states explicitly that no reference integration was consulted, and may report somewhat lower
confidence on patterns a reference would otherwise corroborate (e.g. the exact auth-flow shape). It
will **never** claim to have read a reference integration it didn't actually open this run, and it
will never search your machine for reference packages. It will never invent a provider
implementation from memory to fill the gap.

## 18. How do I use this with Claude?

In Claude Code (or Claude with file access to this repository), just use the Quick Start prompt
above — Claude will read `.ai/skills/shipping-provider-integration/SKILL.md` and its supporting
files directly. No special setup needed; this works whether or not you also have a Claude-specific
skill registered elsewhere in the repository.

## 19. How do I use this with Cursor?

Same Quick Start prompt, in Cursor's chat/agent panel with the repository open. If Cursor doesn't
automatically read the referenced file, explicitly ask it to open and read
`.ai/skills/shipping-provider-integration/SKILL.md` first (most agentic modes will do this
automatically once you reference the path).

## 20. How do I use this with Kiro?

Same Quick Start prompt. If Kiro's interface distinguishes between "context files" and chat
messages, add `.ai/skills/shipping-provider-integration/SKILL.md` (and, if it lets you add a whole
folder, the rest of the skill directory) as context, then send the Quick Start prompt.

## 21. How do I use this with Antigravity?

Same Quick Start prompt — reference the path explicitly in your message. If Antigravity supports
attaching or opening files before chatting, open `SKILL.md` first, then send the prompt.

## 22. How do I run the skill when the tool does not have native skill support?

The whole point of this skill's design is that it doesn't need native skill support. Any AI coding
agent that can read files in your repository can use it:

```
Please read the file .ai/skills/shipping-provider-integration/SKILL.md in this repository,
in full, and follow its instructions exactly. It will tell you which other files in that same
directory to read next. Once you've read the required files, wait for me to provide a Jira ticket
and API documentation, then proceed as instructed.
```

If your tool can't read files at all (pure chat, no repository access), this skill isn't usable
as designed — it depends on the agent being able to read the real Uniware Java source to verify
claims, which requires actual repository access.

---

## FULL WORKFLOW

For developers who want the complete picture, not just the Quick Start:

**Step 1.** You get a Shipping Provider Jira ticket.

**Step 2.** You collect the provider's API documentation (endpoints, auth, sample
request/response, status codes). Optionally, you note the path to any reference integrations you
have locally (e.g. `./reference/shiprocket/`).

**Step 3.** You open the Uniware repository in your AI coding tool of choice.

**Step 4.** You tell the AI: *"Use `.ai/skills/shipping-provider-integration/` for this task"*
(or the fuller Quick Start prompt).

**Step 5.** You provide the Jira and API documentation (pasted or attached).

**Step 6.** The AI reads `SKILL.md`, then the supporting `knowledge/`, `rules/`, and
`schemas/` files it points to, plus the actual Uniware Java source it needs to verify claims.
If you provided a reference path, it reads those files too.

**Step 7.** The AI performs **Phase A only**: understanding, provider API analysis, Uniware
architecture analysis, source properties, connector requirements, authentication, allocation,
label, tracking, cancellation, verification, status mapping, DB requirements, scraper
requirements, assumptions, unknowns, risks, an `IntegrationSpec`, an `ANALYSIS.md`, a confidence
score, and a generation gate. Then it **stops**.

**Step 8.** You review Phase A's output. Check field mappings, the auth pattern, every open
question, and especially any flagged Jira-vs-Uniware conflict.

**Step 9.** Only after your **explicit approval** does the AI perform **Phase B** — and only for
what you approved. If you approved with conditions (e.g. "use Option B for the status conflict"),
those conditions apply.

**Step 10.** The AI generates the integration artifacts, and validates them (well-formed XML,
schema-valid spec, no secrets, no unresolved placeholders, no absolute paths, correct connector
types, correct status-mapping strategy — see `rules/validation-rules.md` for the complete list).

**Step 11.** You perform final review and testing — against a real sandbox, using
`TEST_CHECKLIST.md` — before this integration goes anywhere near production.

---

## TESTABILITY

You can validate that this skill genuinely works the same way across different AI tools by running
the **same Jira ticket** through each of them and comparing the Phase A output:

1. Pick a real (or realistic synthetic) Shipping Provider Jira ticket.
2. In Claude, run the Quick Start prompt with that ticket. Save the `IntegrationSpec.json` and
   `ANALYSIS.md`.
3. In Cursor, run the identical Quick Start prompt with the identical ticket, in a fresh
   conversation. Save its output.
4. Repeat with Kiro, Antigravity, or any other tool you use.
5. Compare: the *facts* (field mappings, entity paths, connector types, status codes) should be
   materially identical across tools, since they all derive from the same `knowledge/`/`rules/`
   files and the same Uniware Java source — not from tool-specific training or tool-specific
   conventions. Differences in wording/formatting are expected; differences in which Uniware
   entity paths or connector types are used should not occur.

The only thing that should differ between tools is **how you invoke the skill** (the exact wording
of "please read this file" varies slightly by tool UI) — never the skill's content or behavior.

---

## Directory reference

See `SKILL.md`'s "Supporting files in this skill" section for the full file tree. In short:
`knowledge/` is what's true about Uniware, `rules/` is what to do about it, `templates/` are
structural stubs (not provider-specific behavior), `schemas/` defines the `IntegrationSpec` format,
`examples/` shows what good output looks like, `validation/` is the post-generation checklist.
