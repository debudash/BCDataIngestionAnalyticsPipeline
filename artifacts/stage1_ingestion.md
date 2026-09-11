# Stage 1 Artifact — Multi-Source Ingestion & Raw Storage

## Design & rationale
- **Three distinct breast-cancer sources**: Synthea (synthetic, code-native), METABRIC and
  TCGA-BRCA (real, via cBioPortal flat files). Chosen for breast specificity + open, keyless download.
- **Land raw, transform later.** Files download to `staging/` then load to Snowflake `RAW` as
  all-VARCHAR tables (`<source>__<file>`). A faithful copy makes Stage 2 reproducible and auditable.
- **Clinical vs genomic split** is declared in `pipeline.yml`, not hardcoded in logic.

## Validation criteria
| Metric | Target |
|---|---|
| Sources landed | 3 / 3 |
| Raw row count vs source file line count | exact match |
| Files with 0 rows | 0 |
| Clinical files identified per source | ≥ 1 |

## Novelty & optimization
- **Manifest-driven ingestion**: adding a 4th source is a YAML edit, not a code change.
- Future: swap `requests` streaming for Snowflake external stages (`COPY INTO` from S3) to skip local disk for large studies.
