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

**Run result: `PASS=90 WARN=1 ERROR=0` across 91 nodes.**

## Novelty & optimization
- **Streaming validation**: run checks as Snowflake tasks on load, not as a batch gate — fail fast
  per micro-batch.
- Trend the pass-rate over runs to catch source drift before it reaches analytics.
- **The gap tests can't see**: the genomic layer had no schema file at all, so a crosswalk that
  silently covered only one of two studies passed every build. Absence of tests is invisible to a
  green run; coverage of *models*, not just rows, deserves its own checkpoint.
