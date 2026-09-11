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
| Warehouse | **Snowflake** (key-pair auth via env vars) | Sponsor has an account; prod target. |
| Genomic data | **Parallel raw layer**, not forced into OMOP | OMOP models clinical facts, not variants. |
| Sources (≥3) | **Synthea (mCODE breast cancer)** + **METABRIC** + **TCGA-BRCA** | All breast-specific; open, direct download. |
| OMOP version | **v5.4** | De-facto standard; all OHDSI tooling targets it (v6.0 unsupported). |
| De-identification | **HIPAA Safe Harbor** (18 identifiers), demonstrated | Deterministic and codeable. Note: sources are already synthetic/de-identified — this stage *demonstrates* the technique. |

## 2. Sources

| # | Source | Type | Content | Access |
|---|---|---|---|---|
| 1 | Synthea mCODE breast cancer | Synthetic | Clinical (SNOMED/LOINC/RxNorm-coded) | Generated / GitHub |
| 2 | METABRIC (`brca_metabric`) | Real | Clinical + genomic | cBioPortal flat files |
| 3 | TCGA-BRCA (`brca_tcga_pan_can_atlas_2018`) | Real | Clinical + genomic | cBioPortal flat files |

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
src/common/                  # config loader + Snowflake I/O (key-pair auth)
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
cp .env.example .env            # fill in Snowflake key-pair details (never committed)
dbt deps                        # install dbt_utils + dbt_expectations
python run_pipeline.py --stage all   # Stage 1 (Python) then dbt build (run + test)
```

`run_pipeline.py` loads `.env` into the environment and points dbt at the project's
`profiles.yml` (which reads the same vars via `env_var`). Run dbt by hand with
`set -a; source .env; set +a; dbt build`.

Prereqs you provide: a Snowflake account + role that can create schemas; OMOP
vocabulary files from [Athena](https://athena.ohdsi.org) as `staging/vocabulary/CONCEPT.csv`;
Java + the Synthea jar for source #1 (or drop pre-generated CSVs in `staging/synthea/csv/`).
