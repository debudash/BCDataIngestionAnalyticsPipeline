# Stage 3 Artifact — Data Quality & Integrity

## Design & rationale
- Follows the **OHDSI Data Quality Dashboard (DQD)** taxonomy: **conformance**, **completeness**,
  **plausibility**. Production can still run full DQD against the same schema.
- **Implemented as dbt tests** — `dbt test` (part of `dbt build`) is the validation run. Generic
  tests plus `dbt_expectations` range checks live beside the models in `_omop.yml`,
  `_genomic.yml` and `_analytics.yml`; a singular test (`tests/assert_death_after_birth.sql`)
  covers cross-table plausibility. Tests co-locate with the models, so validation can't drift.
- **Thresholds tighten as the data earns it.** The condition-mapping check warned while the
  concept map still had open REVIEW rows. Now that every histology resolves, it *fails* instead.
  A permanently-warning test teaches people to ignore warnings.
- **Bounds track the clock, not a literal.** Year-range checks compute from
  `modules.datetime.date.today().year`, so they cannot silently rot.
- **A warning must mean something specific.** The one remaining warning excludes rows that carry
  a coded result, so it flags only rows with neither a number nor a concept.

## Validation criteria (checkpoints)
| Check | Category | Threshold | Result |
|---|---|---|---|
| Every person has a gender concept | conformance | 0 nulls | pass |
| Birth year plausible (1900–today) | plausibility | 0 | pass |
| Conditions mapped to a standard concept | completeness | 0 unmapped | pass |
| Observations mapped to a standard concept | completeness | 0 unmapped | pass |
| Drugs mapped to a standard concept | completeness | 0 unmapped | pass |
| FK integrity to `person` on every fact table | conformance | 0 orphans | pass |
| Genomic sample → person, no orphans | conformance | 0 nulls | pass |
| Sample barcodes unique across both studies | conformance | 0 collisions | pass |
| De-identified tables reference `person_deid` | conformance | 0 orphans | pass |
| Measurement has a value (number or concept) | completeness | warn only | 161 rows, all `NA` |
| Death after birth | plausibility | 0 violations | pass |

**Run result: `PASS=116 WARN=1 ERROR=0` across 117 nodes.**

## Catching absence, not just error

Tests assert things about rows that exist. They are blind to a table nobody built, a model
nobody tested, or a file git never tracked. Three defects this project hit were all that shape:
`OBSERVATION_PERIOD` missing while every build stayed green; a genomic crosswalk covering one of
two studies; eight staging models untracked since the first commit. None was a wrong value.

Absence needs an inventory from **outside** the thing being checked, and the inventory must not
depend on anyone remembering the domain.

**1. The spec is imported, not authored.** `seeds/cdm_v54_tables.csv` is downloaded verbatim
from OHDSI's CommonDataModel repository. It carries an `isRequired` column; exactly two of the
39 tables are marked required, `person` and `observation_period`. Nobody here needs to know that
from memory.

**2. Absence must be signed for.** `seeds/cdm_scope.csv` records a decision for every spec
table: `BUILT`, or `OUT_OF_SCOPE` with a reason. `tests/assert_cdm_coverage.sql` fails three ways:

| Violation | Meaning |
|---|---|
| `MISSING_REQUIRED` | the spec requires it; no model builds it |
| `UNDECLARED` | a spec table nobody ruled in or out — silence, not a decision |
| `NOT_MATERIALIZED` | declared BUILT but absent from the warehouse |

The gate was verified by simulating the original defect: marking `observation_period` as
out-of-scope makes the test fail. A gate that has never fired is not known to work.

**3. Structural gaps are a separate, generic problem.** `dbt_project_evaluator` covers the half
that is not OMOP-specific. It is disabled by default and run deliberately:
`dbt build --select package:dbt_project_evaluator`. On this project it flags 11 categories, of
which two matter here: **22 models with no primary-key test** (the class that hid the genomic
crosswalk bug) and **16 undocumented models**. The rest are dbt naming and directory conventions
that this project deliberately does not follow, because OMOP table names come from the CDM, not
from `fct_`/`dim_` prefixes. Adopt the findings that apply; do not chase the score.

## Novelty & optimization
- **Streaming validation**: run checks as Snowflake tasks on load, not as a batch gate — fail fast
  per micro-batch.
- Trend the pass-rate over runs to catch source drift before it reaches analytics.
- **Field-level conformance is the next increment**: OHDSI publishes
  `OMOP_CDMv5.4_Field_Level.csv` alongside the table list, so the same import-the-spec pattern
  can check that each model carries the required *columns*, not just that the table exists.
- **Run the OHDSI Data Quality Dashboard** against the same schema in production. It encodes
  thousands of checks written by people who know this domain, which is how you borrow expertise
  rather than acquire it. It is an R package, so it belongs in the production story rather than
  the laptop demo.
