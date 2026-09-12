# Stage 4 Artifact — De-Identification & Insight Base

## Design & rationale
- **Method: HIPAA Safe Harbor** (deterministic, codeable). Over an OMOP schema the applicable
  rules are: strip names and source identifiers, keep birth **year** only, aggregate ages > 89,
  and reduce every date tied to an individual to its year.
- **Year truncation, not a date shift.** Safe Harbor permits the year and nothing finer. A
  consistent per-patient shift preserves intervals but is a **Limited Data Set** — a different
  legal basis requiring a data use agreement. The two are not interchangeable, and the label has
  to match what the code does.
- **Full coverage.** One de-identified model per OMOP fact table, plus `mutations_deid` keyed on
  `person_id`, plus `unique_patients` as the roster. A base that covers only some tables pushes
  analysts back to the identified schema, which defeats the purpose.
- **The roster reads only from de-identified models**, so nothing identifying can reach it by
  accident even if an upstream model changes.
- **Honest framing**: sources are already synthetic or de-identified — this stage *demonstrates*
  the method and hardens the pattern for a future real-data source.

## Validation criteria
| Metric | Target | Measured |
|---|---|---|
| DATE / TIMESTAMP columns anywhere in `ANALYTICS` | 0 | 0 |
| Direct identifiers remaining (names, source ids, barcodes, exact DOB) | 0 | 0 |
| Ages present > 89 | 0 | 0 (birth year floored) |
| Row count preserved vs OMOP, per table | 100% | 8 / 8 tables, delta 0 |
| De-identified rows orphaned from `person_deid` | 0 | 0 |
| Re-identification: unique quasi-identifier combos of size 1 | reviewed / k-anon ≥ k | **not yet measured** |

The date rule is verified structurally rather than by sampling:
```sql
select table_name, column_name, data_type
from BREAST_CANCER.INFORMATION_SCHEMA.COLUMNS
where table_schema = 'ANALYTICS'
  and (data_type like '%DATE%' or data_type like '%TIMESTAMP%');
```

## Known limits
- **Genomic data is not made safe by dropping barcodes.** `mutations_deid` removes the sample and
  matched-normal barcodes, which are the *direct* identifiers. A genome-wide variant profile is
  itself potentially re-identifying: enough variants uniquely distinguish an individual and can be
  matched against other genomic datasets. Safe Harbor's eighteen identifiers do not name sequence
  data, and whether it falls under "any other unique identifying characteristic" is contested
  rather than settled. Treat this as de-identified clinical metadata attached to variant calls,
  not as a safe public release.
- **k-anonymity is claimed as a target but not yet measured.** Until it is, the base meets Safe
  Harbor's rules without a stated re-identification risk.
- Safe Harbor's geography rule is not exercised: no source carries an address.

## Novelty & optimization
- **Novel de-identification protocol**: layer k-anonymity / generalization on top of Safe Harbor
  and report the achieved *k* as a quality metric — the obvious next increment.
- Emit a de-id audit log (field → action) as evidence for compliance review.
- Ship a Limited Data Set alongside the Safe Harbor base, with access governed separately, for
  analysts who genuinely need intervals (survival, treatment sequencing).
