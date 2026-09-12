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

Install into a virtualenv, and **activate it**:
```bash
python -m venv .venv
source .venv/Scripts/activate     # Windows/Git Bash; use bin/activate on macOS/Linux
pip install -r requirements.txt
```
**Success:** `dbt --version` prints dbt-core + dbt-snowflake.

> Skipping the activation is the most common first failure: `run_pipeline.py` shells out to
> `dbt`, so an inactive venv dies at Stage 2 with `[WinError 2] The system cannot find the
> file specified`.

---

## 1. Snowflake credentials

The pipeline supports two auth methods. **Key-pair is the default** and works on any account.

Generate a key pair and register the **public** key on your Snowflake user:
```bash
openssl genrsa 2048 | openssl pkcs8 -topk8 -inform PEM -out rsa_key.p8 -nocrypt
openssl rsa -in rsa_key.p8 -pubout -out rsa_key.pub
```
In Snowflake, in a worksheet running as `ACCOUNTADMIN` (altering a user needs it — `SYSADMIN`
fails), paste the body of `rsa_key.pub` without the header/footer lines:
```sql
ALTER USER <YOUR_USER> SET RSA_PUBLIC_KEY='MIIBIjANBgkq...';
CREATE DATABASE IF NOT EXISTS BREAST_CANCER;
DESC USER <YOUR_USER>;            -- check RSA_PUBLIC_KEY_FP took
```
Then fill in `.env`:
```bash
cp .env.example .env
# edit .env: SNOWFLAKE_ACCOUNT, _USER, _DATABASE=BREAST_CANCER, _PRIVATE_KEY_PATH=./rsa_key.p8
```

Get the account identifier from Snowsight: click your account name (bottom left), hover the
account row, **Copy account identifier**. Use the hyphen form `MYORG-MYACCOUNT`.
`CURRENT_ACCOUNT()` returns only half of it and is not what you want here.

**Browser SSO** is the alternative: uncomment `SNOWFLAKE_AUTHENTICATOR=externalbrowser` in
`.env`. It needs a SAML identity provider configured on the account, which trial accounts do
not have — without one it fails with `390190 ... SAML Identity Provider`. The connector caches
the token, so a run prompts once rather than once per table.

**Success:** `python -c "from src.common.snowflake_io import run_sql; print(run_sql('select current_version()'))"`
prints a version.

> Safety: `.env`, `*.p8`, `rsa_key*` are git-ignored. Never commit them.

---

## 2. OMOP vocabulary (for code-resolve joins)

1. Go to <https://athena.ohdsi.org>, create a free account.
2. Request **SNOMED, LOINC, RxNorm, Cancer Modifier, ICDO3, NAACCR**. Gender, Race, Ethnicity,
   UCUM and the metadata vocabularies are auto-included and are not selectable checkboxes —
   searching for "UCUM" finds nothing, which is expected.
3. Wait for the email, then unzip.
4. Place `CONCEPT.csv` at `staging/vocabulary/CONCEPT.csv`.

**If Athena sends more than one bundle** (separate requests arrive as separate zips, each with
its own `CONCEPT.csv`), merge them into a single file first, deduplicating on `concept_id`.
Stage 1 loads exactly one `CONCEPT.csv`.

**Success:** tab-delimited with a `concept_id` header. Check what you got:
```bash
awk -F'\t' 'NR>1 {print $4}' staging/vocabulary/CONCEPT.csv | sort -u
```
**If you skip this:** the pipeline still runs, but clinical codes resolve to `concept_id = 0`.

---

## 3. Synthea breast-cancer patients (source #1)

```bash
java -jar synthea-with-dependencies.jar -m breast_cancer -p 5000 \
  --exporter.csv.export true --exporter.baseDirectory ./staging/synthea
```
…or drop pre-generated `patients.csv, conditions.csv, medications.csv, observations.csv,
encounters.csv` into `staging/synthea/csv/`.

**Use `-p 5000`, not 500.** The module's cancer incidence is low: 500 patients yields about
6 diagnoses, which is too thin to demonstrate anything. 5000 yields roughly 84, and takes a
few minutes.

**Success:** `ls staging/synthea/csv/*.csv` lists the files, and `conditions.csv` has more
than a handful of rows.
(METABRIC and TCGA-BRCA download automatically in Step 4 — no manual step.)

---

## 4. Run it

```bash
python run_pipeline.py --stage all
```
This runs, in order:
1. **Stage 1 (Python):** downloads METABRIC + TCGA files, loads all sources to `RAW`,
   loads `VOCAB.CONCEPT`.
2. **`dbt deps`:** installs dbt_utils + dbt_expectations.
3. **`dbt build`:** seeds `concept_map`, runs staging → omop → genomic → analytics models,
   and runs all tests.

**Success:** ends with `Done.` and dbt reports `ERROR=0` (one warning is expected — see below).

Run a single stage while iterating:
```bash
python run_pipeline.py --stage 1     # ingest only
python run_pipeline.py --stage 2     # dbt seed + run (staging, omop, genomic)
python run_pipeline.py --stage 4     # dbt run (analytics / de-id)
python run_pipeline.py --stage 3     # dbt test (validation)
```

> **Run stage 4 before stage 3.** The flags are numbered by lifecycle, not by dependency:
> stage 3 tests the analytics models that stage 4 builds, so `--stage 3` on a fresh warehouse
> errors with *schema ANALYTICS does not exist*. `--stage all` uses `dbt build` and orders
> everything correctly.

### Where the real study files come from

`download.cbioportal.org`, which serves whole-study tarballs, is unreachable from some
networks (DNS resolves, TCP never connects). Ingest pulls the four files declared in
`config/pipeline.yml` from the **cBioPortal datahub on GitHub** instead, one at a time, which
also skips several hundred MB of expression and methylation data no model reads.

TCGA-BRCA's `data_mutations.txt` is missing upstream (its Git LFS object returns *does not
exist on the server*). Stage 1 falls back to the **cBioPortal REST API** and writes those rows
under METABRIC's MAF column names, so both mutation tables share one shape.

---

## 5. Verify the output

```sql
-- run in a Snowflake worksheet on the BREAST_CANCER database
SELECT COUNT(*) FROM OMOP.PERSON;                  -- patients across all 3 sources
SELECT COUNT(*) FROM OMOP.CONDITION_OCCURRENCE;    -- Synthea events + real-source diagnoses
SELECT * FROM ANALYTICS.UNIQUE_PATIENTS LIMIT 20;  -- the de-identified roster

-- Safe Harbor holds only if this returns nothing:
SELECT table_name, column_name, data_type
FROM BREAST_CANCER.INFORMATION_SCHEMA.COLUMNS
WHERE table_schema = 'ANALYTICS'
  AND (data_type LIKE '%DATE%' OR data_type LIKE '%TIMESTAMP%');
```

Run the completeness reconciliation, which checks raw patients → OMOP persons per source and
mapped-vs-unmapped concept counts in one result set:
```bash
dbt compile --select reconciliation
# then run target/compiled/breast_cancer_omop/analyses/reconciliation.sql in Snowflake
```
Expect `person` deltas of 0.

Browse the dbt docs site for the DAG and every model's lineage:
```bash
set -a; source .env; set +a
dbt docs generate && dbt docs serve
```

---

## Troubleshooting

| Symptom | Likely cause / fix |
|---|---|
| `[WinError 2] The system cannot find the file specified` at Stage 2 | The venv is not activated, so `dbt` is not on PATH. See Step 0. |
| `dbt` can't find a profile | Run from the project root, or `export DBT_PROFILES_DIR=$(pwd)`. `run_pipeline.py` sets this for you. |
| Auth error on connect | Public key not registered, or `SNOWFLAKE_PRIVATE_KEY_PATH` wrong. Re-check Step 1. |
| `390190 ... SAML Identity Provider` | `SNOWFLAKE_AUTHENTICATOR=externalbrowser` on an account with no identity provider. Comment it out to use the key pair. |
| `schema ANALYTICS does not exist` during tests | Stage 3 ran before Stage 4. See the note in Step 4. |
| A `stg_metabric__*` / `stg_tcga_brca__*` model fails on a missing column | The real file header differs from `concept_map.csv`. Fix the column name **in that staging model only**. TCGA's `ER_STATUS_BY_IHC` was one of these: the column does not exist in either TCGA clinical file. |
| `invalid identifier 'CONCEPT_ID'` | `VOCAB.CONCEPT` loaded with lowercase column names. Stage 1 uppercases them; reload the vocabulary. |
| `not_null_measurement_value_as_number` warns | Expected. Those rows carry a coded result (`value_as_concept_id`) or an `NA`, not a number. |
