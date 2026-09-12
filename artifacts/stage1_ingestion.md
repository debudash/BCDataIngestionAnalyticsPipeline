# Stage 1 Artifact — Multi-Source Ingestion & Raw Storage

## Design & rationale
- **Three distinct breast-cancer sources**: Synthea (synthetic, code-native), METABRIC and
  TCGA-BRCA (real, from cBioPortal). Chosen for breast specificity + open, keyless download.
- **Land raw, transform later.** Files download to `staging/` then load to Snowflake `RAW` as
  all-VARCHAR tables (`<source>__<file>`). A faithful copy makes Stage 2 reproducible and auditable.
- **Clinical vs genomic split** is declared in `pipeline.yml`, not hardcoded in logic.
- **Per-file fetch, not per-study tarball.** `download.cbioportal.org` proved unreachable from
  some networks (DNS resolves, TCP never connects), so studies are pulled file by file from the
  cBioPortal **datahub on GitHub**. This also skips several hundred MB of expression and
  methylation data no model reads.
- **A documented fallback chain.** TCGA-BRCA's `data_mutations.txt` is missing upstream (its Git
  LFS object returns *does not exist on the server*). Ingest falls back to the cBioPortal **REST
  API** and writes those rows under METABRIC's MAF column names, so both mutation tables share
  one shape. Fallbacks are in the loader, not in a person's head.

## Validation criteria
| Metric | Target | Measured |
|---|---|---|
| Sources landed | 3 / 3 | 3 / 3 |
| Study files obtained | 8 / 8 | 7 datahub + 1 REST API |
| RAW tables created | one per file | 21 |
| Files with 0 rows | 0 | 0 |
| Vocabulary concepts loaded | > 1M | 2,068,712 |
| Mutation tables sharing one column set | yes | 45 MAF columns each |

## Novelty & optimization
- **Manifest-driven ingestion**: adding a 4th source is a YAML edit, not a code change.
- **Degrade, don't fail**: a missing file costs one RAW table, not the run.
- Future: swap `requests` streaming for Snowflake external stages (`COPY INTO` from S3) to skip
  local disk for large studies. Stage 1 currently reloads everything; incremental load by file
  checksum would cut the rerun cost.
