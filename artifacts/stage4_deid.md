# Stage 4 Artifact — De-Identification & Insight Base

## Design & rationale
- **Method: HIPAA Safe Harbor** (deterministic, codeable). Over an OMOP schema the applicable rules
  are: strip names/source ids, keep birth **year** only, cap ages > 89, generalize geography to state,
  optional consistent per-person date shift.
- Output lands in `ANALYTICS` schema; `UNIQUE_PATIENTS` is the de-identified roster feeding the insight engine.
- **Honest framing**: sources are already synthetic/de-identified — this stage *demonstrates* the method
  and hardens the pattern for a future real-data source.

## Validation criteria
| Metric | Target |
|---|---|
| Direct identifiers remaining (name, source_value, exact DOB) | 0 |
| Ages present > 89 | 0 (capped at 90) |
| Re-identification: unique quasi-identifier combos of size 1 | reviewed / k-anon ≥ k |
| Row count preserved vs OMOP | 100% |

## Novelty & optimization
- **Novel de-identification protocol**: layer k-anonymity / generalization on top of Safe Harbor and
  report the achieved *k* as a quality metric.
- Emit a de-id audit log (field → action) as evidence for compliance review.
