# Stage 2 Artifact — OMOP CDM v5.4 Mapping

## Design & rationale
- **Target: OMOP CDM v5.4** — the version all OHDSI tooling supports.
- **Implemented in dbt.** `models/staging/` cleans RAW into typed views; `models/omop/` builds the
  CDM tables; layering and schemas are declared in `dbt_project.yml`.
- **Mapping is data, not code.** `seeds/concept_map.csv` is loaded via `dbt seed` and the OMOP
  models **join against it** (`ref('concept_map')`) — the reviewed doc *is* the executed contract.
- **Two mapping styles**: value-map (demographics → fixed standard concept_ids via the seed) and
  code-resolve (SNOMED/LOINC/RxNorm codes → standard concept_id via the Athena `CONCEPT` source).
- **Genomic stays parallel** (`models/genomic/`, `GENOMIC` schema) with a `sample_person` crosswalk.
- Synthea models follow the **OHDSI dbt-synthea** pattern; custom rows cover oncology-specific fields.

## Validation criteria
| Metric | Target |
|---|---|
| `concept_map.csv` rows with `review_status=REVIEW` unresolved | 0 before sign-off |
| Standard-concept mapping rate (non-zero `_concept_id`) | ≥ 90% clinical rows |
| Rows with `concept_id = 0` (unmapped) | quarantined & counted |
| Genomic samples linked to a person | ≥ 95% |

## Novelty & optimization
- **Automated vocabulary mapping**: nightly refresh of concept_ids by re-joining Athena vocab —
  mappings self-heal as vocabularies update.
- Candidate mappings for REVIEW rows could be proposed by an LLM against SNOMED/LOINC and staged for human approval.
