# Breast Cancer Data Ingestion & Analytics Pipeline

An end-to-end **ELT** pipeline that ingests multi-source breast cancer data, harmonizes the
**clinical** elements into the **OMOP Common Data Model (CDM v5.4)**, validates quality,
and produces a de-identified analytics base. Genomic data is kept as a **parallel
enrichment layer** (OMOP is clinical-first and does not model gene variants cleanly).

**Stack:** Python for extract/load (Stage 1) → **dbt on Snowflake** for transform,
validation, and de-identification (Stages 2–4). dbt fits because Stages 2–4 are all
SQL-on-warehouse: OMOP tables are **models**, the concept map is a **seed**, and the
quality checks are **dbt tests**.

> This README is the **refined Project Initiation Document (PID)**. It is the baseline
> for implementation. Every design decision below was locked with the project sponsor.

---

## 1. Locked decisions

| Question | Decision | Rationale |
|---|---|---|
| Warehouse | **Snowflake** (key-pair auth via env vars) | Sponsor has an account; prod target. Browser SSO is selectable via `SNOWFLAKE_AUTHENTICATOR`, but needs a SAML identity provider on the account. |
| Genomic data | **Parallel raw layer**, not forced into OMOP | OMOP models clinical facts, not variants. |
| Sources (≥3) | **Synthea (mCODE breast cancer)** + **METABRIC** + **TCGA-BRCA** | All breast-specific; open, direct download. |
| OMOP version | **v5.4** | De-facto standard; all OHDSI tooling targets it (v6.0 unsupported). |
| De-identification | **HIPAA Safe Harbor** (18 identifiers), demonstrated | Deterministic and codeable. Note: sources are already synthetic/de-identified — this stage *demonstrates* the technique. |

## 2. Sources

| # | Source | Type | Content | Access |
|---|---|---|---|---|
| 1 | Synthea mCODE breast cancer | Synthetic | Clinical (SNOMED/LOINC/RxNorm-coded) | Generated / GitHub |
| 2 | METABRIC (`brca_metabric`) | Real | Clinical + genomic | cBioPortal datahub (GitHub) |
| 3 | TCGA-BRCA (`brca_tcga_pan_can_atlas_2018`) | Real | Clinical + genomic | cBioPortal datahub (GitHub) + REST API |

The two real studies are pulled **file by file** from the [cBioPortal datahub](https://github.com/cBioPortal/datahub) rather than as whole-study tarballs: we take only the
four files `config/pipeline.yml` declares and skip the expression and methylation data no model
reads. `download.cbioportal.org`, which serves the tarballs, is unreachable from some networks.

TCGA-BRCA's `data_mutations.txt` is the one file the datahub cannot serve — its Git LFS object is
absent upstream. Stage 1 falls back to the public cBioPortal REST API and writes those rows under
the same MAF column names METABRIC's file uses, so both mutation tables share one shape.

## 3. Lifecycle stages

```
Stage 1  Ingest      Python:  3 sources -> local staging/ -> Snowflake RAW (+ VOCAB.CONCEPT)
Stage 2  Map to OMOP dbt run: RAW -> staging views -> OMOP CDM v5.4 models + genomic models
                     driven by the concept_map SEED  <-- THE REVIEW CONTRACT
Stage 3  Validate    dbt test: conformance / completeness / plausibility on the OMOP models
Stage 4  De-identify dbt run: Safe Harbor models -> analytics schema (unique-patient roster)
```

Each stage emits a **design/rationale**, **validation criteria**, and **novelty** note under `artifacts/`.

## 4. The concept-mapping review gate

Stage 2 is the intellectual core. The dbt models do **not** hardcode mappings — the reviewed
`seeds/concept_map.csv` is loaded as a table (`dbt seed`) and the OMOP models **join against
it**. That file is rendered for human review as the **OMOP Concept Mapping** artifact.
**Review and approve it before trusting Stage 2 output.** Standard-demographic `concept_id`s
are stable and included; clinical codes are resolved by joining the Athena `CONCEPT` vocabulary
on `(vocabulary_id, concept_code)`.

## 5. Layout

```
config/pipeline.yml          # Stage 1 sources, Snowflake targets, OMOP version
seeds/concept_map.csv        # source field/value -> OMOP concept (the review contract, a dbt seed)
src/common/                  # config loader + Snowflake I/O (key-pair auth, or browser SSO)
src/stage1_ingest/           # download Synthea + cBioPortal; load RAW + VOCAB (Python)
dbt_project.yml              # dbt project (Stages 2-4)
profiles.yml · packages.yml  # dbt connection (env_var) + package deps
macros/                      # schema-naming helper
models/staging/              # views cleaning RAW
models/omop/                 # OMOP CDM v5.4 models + tests (Stage 2 + Stage 3)
models/genomic/              # parallel non-OMOP layer
models/analytics/            # Safe Harbor de-identified models (Stage 4)
tests/                       # singular data-quality tests
run_pipeline.py              # Python EL, then dbt deps + build
artifacts/                   # per-stage rationale / validation / novelty notes
```

## 6. Run

```bash
pip install -r requirements.txt
cp .env.example .env            # fill in Snowflake auth — key-pair or SSO; see .env.example (never committed)
dbt deps                        # install dbt_utils + dbt_expectations
python run_pipeline.py --stage all   # Stage 1 (Python) then dbt build (run + test)
```

`run_pipeline.py` loads `.env` into the environment and points dbt at the project's
`profiles.yml` (which reads the same vars via `env_var`). Run dbt by hand with
`set -a; source .env; set +a; dbt build`.

Prereqs you provide: a Snowflake account + role that can create schemas; OMOP
vocabulary files from [Athena](https://athena.ohdsi.org) as `staging/vocabulary/CONCEPT.csv`;
Java + the Synthea jar for source #1 (or drop pre-generated CSVs in `staging/synthea/csv/`).

`RUNBOOK.md` walks the first end-to-end run step by step. Three things that bite on the way:

**Run stage 4 before stage 3.** The per-stage flags are numbered by lifecycle, not by
dependency: stage 3 tests the analytics models that stage 4 builds, so `--stage 3` on a fresh
warehouse errors with *schema ANALYTICS does not exist*. Use `--stage all`, which runs
`dbt build` and orders everything correctly, or run `4` then `3` by hand.

**Athena may hand you more than one bundle.** Vocabularies requested in separate downloads
arrive as separate zips, each with its own `CONCEPT.csv`. Stage 1 loads exactly one file, so
merge them into `staging/vocabulary/CONCEPT.csv` first, deduplicating on `concept_id`.

**Install into a virtualenv and activate it.** `run_pipeline.py` shells out to `dbt`, so an
unactivated venv fails at stage 2 with *[WinError 2] The system cannot find the file specified*.

### What a good run looks like

| Table | Rows |
|---|---|
| `OMOP.PERSON` | 4,093 (METABRIC 2,509 · TCGA 1,084 · Synthea 500) |
| `OMOP.MEASUREMENT` | 24,089 |
| `OMOP.OBSERVATION` | 10,575 |
| `OMOP.VISIT_OCCURRENCE` | 4,822 |
| `OMOP.CONDITION_OCCURRENCE` | 3,599 (all resolved to a real `concept_id`) |
| `GENOMIC.SAMPLE_PERSON` | 2,509 |
| `ANALYTICS.UNIQUE_PATIENTS` | 4,093 |
| `OMOP.DEATH` | 0 |

`dbt test` ends **PASS=26 WARN=1 ERROR=0**. The warning is
`not_null_measurement_value_as_number`: receptor status is text held in `value_source_value`,
and mapping Positive/Negative to a standard `value_as_concept_id` is a REVIEW item.

Three empty-looking results that are correct, not bugs:

- **`DEATH` is empty.** No Synthea patient has a death date, and METABRIC's `OS_STATUS`
  (`0:LIVING` / `1:DECEASED`) is a REVIEW row — survival months only approximate a death date,
  so the mapping is deliberately unbuilt.
- **`year_of_birth` is null for 3,593 of 4,093 people.** Only Synthea carries birth dates; the
  real sources give age at diagnosis, and deriving a birth year from it is another REVIEW item.
- **15,258 measurements map to `concept_id = 0`.** All of them are Synthea's QALY, DALY and
  QOLS quality-of-life scores, which have no LOINC equivalent. The vocabulary is working.

### Verifying completeness

To confirm every downloaded file landed and every model built, check three things:

1. **Tables/models created** — `dbt build` reports `ERROR=0`; cross-check against the warehouse:
   ```sql
   select table_schema, table_name, table_type, row_count
   from BREAST_CANCER.INFORMATION_SCHEMA.TABLES
   where table_schema in ('RAW','STAGING','OMOP','GENOMIC','ANALYTICS','VOCAB')
   order by table_schema, table_name;
   ```
   Every name from `dbt ls --resource-type model` should appear (staging shows as `VIEW`).
2. **Files loaded** — one RAW table per downloaded file; the Stage 1 log prints rows per table.
3. **Flow-through** — run the reconciliation analysis, which checks raw patients → OMOP persons
   per source and mapped-vs-unmapped concept counts in one result set:
   ```bash
   dbt compile --select reconciliation
   # then run target/compiled/breast_cancer_omop/analyses/reconciliation.sql in Snowflake
   ```
   Expect `person` deltas of 0, and `mapping` deltas that match the known unmapped set above.
