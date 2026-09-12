# Stage 2 Artifact — OMOP CDM v5.4 Mapping

## Design & rationale
- **Target: OMOP CDM v5.4** — the version all OHDSI tooling supports.
- **Implemented in dbt.** `models/staging/` cleans RAW into typed views; `models/omop/` builds the
  CDM tables; layering and schemas are declared in `dbt_project.yml`.
- **Mapping is data, not code.** `seeds/concept_map.csv` is loaded via `dbt seed` and the OMOP
  models **join against it** (`ref('concept_map')`) — the reviewed doc *is* the executed contract.
- **Three mapping styles**, and which one applies is itself a design decision:
  - *value map* — the source writes its own words (`Positive`, `1:DECEASED`, `STAGE IIA`); a human
    picks the target concept and the seed carries it inline.
  - *code resolve* (`RESOLVE_AT_ETL`) — the source already carries SNOMED/LOINC/RxNorm; the
    vocabulary does the work and **no human decision is needed**. Drug and procedure exposure are
    entirely this kind.
  - *declined* (`NOT_MAPPED`) — examined and refused, with the reason in `notes`. This is what
    makes the gate real: a declined row reads differently from one nobody has looked at.
- **Concept vs value are separate columns.** `observation_concept_id` says *what is being
  observed*; `value_as_concept_id` says *what the answer is*. Coding one does not code the other.
- **OMOP routes a row by its concept's domain.** Histologic grade moved from OBSERVATION to
  MEASUREMENT because its concept (LOINC 44648-4) is Measurement-domain.
- **Genomic stays parallel** (`models/genomic/`, `GENOMIC` schema) with a `sample_person` crosswalk
  covering both real studies.

## Validation criteria
| Metric | Target | Measured |
|---|---|---|
| `concept_map.csv` rows still `REVIEW` | 0 before sign-off | 0 |
| Conditions with a standard concept | 100% | 3,677 / 3,677 |
| Observations with a standard concept | 100% | 10,047 / 10,047 |
| Drug exposures resolved via RxNorm | 100% | 224 / 224 |
| Procedures resolved via SNOMED | ≥ 99% | 3,452 / 3,471 |
| Genomic samples linked to a person | ≥ 95% | 3,593 / 3,593 |
| Measurements at `concept_id = 0` | counted & explained | 151,683 (Synthea QALY/DALY/QOLS) |

## Novelty & optimization
- **Automated vocabulary mapping**: nightly refresh of concept_ids by re-joining Athena vocab —
  mappings self-heal as vocabularies update.
- **LLM-proposed candidates, human approval**: the twelve REVIEW rows were closed by querying the
  loaded vocabulary for candidates, presenting each with its source distribution and consequence,
  and recording the decision. That workflow is automatable up to, but not through, the approval.
- The 19 unresolved procedures are non-standard SNOMED codes that need `CONCEPT_RELATIONSHIP`
  (*Maps to*) to reach a standard concept. Loading that table would close them.
