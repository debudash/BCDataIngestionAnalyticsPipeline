# Stage 3 Artifact — Data Quality & Integrity

## Design & rationale
- Follows the **OHDSI Data Quality Dashboard (DQD)** taxonomy: **conformance**, **completeness**,
  **plausibility**. Production can still run full DQD against the same schema.
- **Implemented as dbt tests** — `dbt test` (part of `dbt build`) is the validation run. Generic
  tests (`not_null`, `unique`, `relationships`, `accepted_values`) plus `dbt_expectations` range
  checks live in `models/omop/_omop.yml`; a singular test (`tests/assert_death_after_birth.sql`)
  covers cross-table plausibility. Tests co-locate with the models, so validation can't drift from them.

## Validation criteria (checkpoints)
| Check | Category | Threshold |
|---|---|---|
| Every person has a gender concept | conformance | 0 nulls |
| Birth year plausible (1900–today) | plausibility | 0 |
| Conditions mapped to a standard concept | completeness | 0 unmapped |
| Condition→person FK integrity | conformance | 0 orphans |
| Measurement has a value | completeness | 0 empty |
| Death after birth | plausibility | 0 violations |

## Novelty & optimization
- **Streaming validation**: run checks as Snowflake tasks on load, not as a batch gate — fail fast per micro-batch.
- Trend the pass-rate over runs to catch source drift before it reaches analytics.
