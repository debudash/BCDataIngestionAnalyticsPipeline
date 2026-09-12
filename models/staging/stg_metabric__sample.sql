-- METABRIC sample-level clinical (cBioPortal data_clinical_sample.txt).
-- Column names follow concept_map.csv; verify against the real header and fix here.
select
    "PATIENT_ID"                as person_source_value,
    "SAMPLE_ID"                 as sample_id,
    "CANCER_TYPE_DETAILED"      as cancer_type_detailed,
    "ER_STATUS"                 as er_status,
    "PR_STATUS"                 as pr_status,
    "HER2_STATUS"               as her2_status,
    "TUMOR_STAGE"               as tumor_stage,
    "GRADE"                     as grade,
    try_to_double("TUMOR_SIZE") as tumor_size_mm
from {{ source('raw', 'metabric__data_clinical_sample') }}
