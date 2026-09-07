# Prerequisite check

Run this before Phase A of any real generation task.

## Procedure

1. Resolve the repository root: `REPO_ROOT=$(git rev-parse --show-toplevel)`.
2. Check tier 1 paths below. If any is missing, **stop** — this is a hard prerequisite failure.
3. Check tier 2 (reference package). This is **optional** — only applies if the developer
   explicitly provides a reference path. If no path is provided, skip entirely.
4. Proceed to Phase A, carrying forward whether a reference was provided and available.

## Tier 1 — Uniware source (hard requirement)

```
UniwareCore/src/main/java/com/uniware/core/entity/ShippingProviderSource.java
UniwareCore/src/main/java/com/uniware/core/entity/ShippingSourceConnector.java
UniwareCore/src/main/java/com/uniware/core/entity/ShipmentTrackingStatusMapping.java
UniwareCore/src/main/java/com/uniware/core/entity/ShipmentTracking.java
UniwareServices/src/main/java/com/uniware/services/shipping/AbstractShipmentHandler.java
UniwareServices/src/main/java/com/uniware/services/shipping/impl/ShippingProviderServiceImpl.java
UniwareServices/src/main/java/com/uniware/services/shipping/impl/ShippingAdminServiceImpl.java
UniwareServices/src/main/java/com/uniware/services/shipping/impl/DispatchServiceImpl.java
UniwareServices/src/main/java/com/uniware/services/shipping/impl/ScrapedShipmentHandler.java
UniwareServices/src/main/java/com/uniware/services/configuration/ShippingConfiguration.java
UniwareServices/src/main/java/com/uniware/services/shipping/impl/ShipmentTrackingServiceImpl.java
```

If any of these is missing, stop and report:

```
Required Uniware source file is missing.

Expected:
<the specific missing path>

This is a prerequisite for reliable analysis — please confirm this is a complete Uniware checkout
before proceeding.
```

Do not proceed with reduced confidence in place of stopping for a tier-1 gap. This skill's rules
and templates are derived from and cite this source directly — without it, nothing in this skill
can be verified against ground truth.

## Tier 2 — Reference integration package (optional, developer-supplied)

**Never discover or search for reference integrations automatically.** Use references only when
the developer explicitly provides a reference path in their prompt for that run.

There is no hardcoded path to check. The procedure is:

- **Developer provides a reference path** (e.g. `Reference path: ./my-references/` or
  `Reference path: /absolute/path/to/Ref/`): resolve that path (prefer repository-relative),
  check whether it exists and is non-empty (contains at least one provider subdirectory). If it
  exists, use it as pattern material — read the specific files actually consulted, cite them, and
  never claim a provider was consulted if its subdirectory wasn't actually opened during this run.
- **Developer provides no reference path**: skip reference integrations completely. Do not search
  for them. State explicitly in the analysis output, verbatim or close to it:

  ```
  No reference integration path was provided for this run.
  This analysis was produced from Uniware source (knowledge/*.md, rules/*.md) and the
  provider's own API documentation only. No existing integration was inspected. Where this
  skill's bundled knowledge doesn't cover a needed pattern (e.g. a specific auth flow shape),
  that gap is listed under Assumptions/Questions below rather than inferred from an unavailable
  reference.
  ```

Never write a "Reference Selection" section (Phase A step 2 of the two-phase workflow) that names
a specific reference provider as "closest" if a reference path was not actually provided and read
during that run. This is the specific failure mode the optional-reference design exists to
prevent — do not let familiarity with providers' general shapes (from training data or from a
prior session) stand in for actually having read the file this run.

## Missing Uniware-source report format (tier 1)

```
Required Uniware source file is missing.

Expected:
<path>

This is a prerequisite for reliable analysis — please confirm this is a complete Uniware checkout
before proceeding.
```

Do not soften this message, do not proceed past it, and do not substitute a description of what
the missing file "probably" contains.
