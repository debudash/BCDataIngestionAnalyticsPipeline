# RUNBOOK — first end-to-end run

A step-by-step for taking the pipeline from a clean checkout to a validated OMOP schema
in your Snowflake. Follow top to bottom; each step says what "success" looks like.

Shell examples use bash. On Windows, run these in Git Bash (the `source .env` trick needs it).

---

## 0. Prerequisites (one-time)

| Need | How |
|---|---|
| Python 3.10+ | `python --version` |
| Java 11+ (for Synthea) | `java -version` — or skip and drop pre-made CSVs (Step 3) |
| A Snowflake account + a role that can `CREATE SCHEMA` | e.g. `SYSADMIN` on a dev database |
| An RSA key pair registered on your Snowflake user | see Step 1 |

```bash
pip install -r requirements.txt
```
**Success:** `dbt --version` prints dbt-core + dbt-snowflake.

---

## 1. Snowflake credentials (key-pair auth)

Generate a key pair and register the **public** key on your Snowflake user:
```bash
openssl genrsa 2048 | openssl pkcs8 -topk8 -inform PEM -out rsa_key.p8 -nocrypt
openssl rsa -in rsa_key.p8 -pubout -out rsa_key.pub
```
In Snowflake (run as an admin), attach the public key (paste the body of `rsa_key.pub`
without the header/footer lines):
```sql
ALTER USER <YOUR_USER> SET RSA_PUBLIC_KEY='MIIBIjANBgkq...';
CREATE DATABASE IF NOT EXISTS BREAST_CANCER;
```
Then fill in `.env`:
```bash
cp .env.example .env
# edit .env: SNOWFLAKE_ACCOUNT, _USER, _DATABASE=BREAST_CANCER, _PRIVATE_KEY_PATH=./rsa_key.p8
```
**Success:** `python -c "from src.common.snowflake_io import run_sql; print(run_sql('select current_version()'))"`
prints a version. (Loads `.env`, connects with your key.)

> Safety: `.env`, `*.p8`, `rsa_key*` are git-ignored. Never commit them.

---

## 2. OMOP vocabulary (for code-resolve joins)

1. Go to <https://athena.ohdsi.org>, create a free account.
2. Download at least **SNOMED, LOINC, RxNorm** (and Gender/Race/Ethnicity — included by default).
3. Unzip and place `CONCEPT.csv` at `staging/vocabulary/CONCEPT.csv`.

**Success:** the file exists and is tab-delimited with a `concept_id` header.
**If you skip this:** the pipeline still runs, but SNOMED/LOINC codes resolve to `concept_id = 0`
and the "condition mapped" test will *warn* (by design).

---

## 3. Synthea breast-cancer patients (source #1)

Either generate them:
```bash
java -jar synthea-with-dependencies.jar -m breast_cancer -p 500 \
  --exporter.csv.export true --exporter.baseDirectory ./staging/synthea
```
…or drop pre-generated `patients.csv, conditions.csv, observations.csv, encounters.csv`
into `staging/synthea/csv/`.

**Success:** `ls staging/synthea/csv/*.csv` lists the files.
(METABRIC and TCGA-BRCA download automatically in Step 4 — no manual step.)

---

## 4. Run it

```bash
python run_pipeline.py --stage all
```
This runs, in order:
1. **Stage 1 (Python):** downloads METABRIC + TCGA tarballs, loads all sources to `RAW`,
   loads `VOCAB.CONCEPT`.
2. **`dbt deps`:** installs dbt_utils + dbt_expectations.
3. **`dbt build`:** seeds `concept_map`, runs staging → omop → genomic → analytics models,
   and runs all tests.

**Success:** ends with `Done.` and dbt reports `PASS` (warnings are acceptable — see below).

Run a single stage while iterating:
```bash
python run_pipeline.py --stage 1     # ingest only
python run_pipeline.py --stage 2     # dbt seed + run (staging, omop, genomic)
python run_pipeline.py --stage 3     # dbt test (validation)
python run_pipeline.py --stage 4     # dbt run (analytics / de-id)
```

---

## 5. Verify the output

```sql
-- run in a Snowflake worksheet on the BREAST_CANCER database
SELECT COUNT(*) FROM OMOP.PERSON;                 -- patients across all 3 sources
SELECT COUNT(*) FROM OMOP.CONDITION_OCCURRENCE;   -- Synthea events + real-source diagnoses
SELECT * FROM ANALYTICS.UNIQUE_PATIENTS LIMIT 20; -- the de-identified insight base
```
Browse the dbt docs site for the DAG and every model's lineage:
```bash
set -a; source .env; set +a
dbt docs generate && dbt docs serve
```

---

## Troubleshooting

| Symptom | Likely cause / fix |
|---|---|
| `dbt` can't find a profile | Run from the project root, or `export DBT_PROFILES_DIR=$(pwd)`. `run_pipeline.py` sets this for you. |
| Auth error on connect | Public key not registered, or `SNOWFLAKE_PRIVATE_KEY_PATH` wrong. Re-check Step 1. |
| A `stg_metabric__*` / `stg_tcga__*` model fails on a missing column | The real file header differs from `concept_map.csv`. Fix the column name **in that staging model only**. |
| "condition mapped" test **warns** | Vocabulary not loaded (Step 2), so codes resolve to 0. Expected until vocab is present. |
| Receptor status has no `value_as_concept_id` | By design — that's a REVIEW item on the concept-map artifact, pending sign-off. |
