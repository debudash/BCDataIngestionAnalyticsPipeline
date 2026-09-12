-- TCGA-BRCA sample-level clinical (cBioPortal data_clinical_sample.txt).
-- Column names follow concept_map.csv; verify against the real header and fix here.
select
    "PATIENT_ID"            as person_source_value,
    "SAMPLE_ID"             as sample_id,
    "CANCER_TYPE_DETAILED"  as cancer_type_detailed,
    -- This TCGA study carries no receptor status: neither data_clinical_sample.txt nor
    -- data_clinical_patient.txt has an ER column. Held as null so MEASUREMENT keeps one
    -- shape across sources; its null-filter drops these rows rather than storing blanks.
    cast(null as varchar)   as er_status
from {{ source('raw', 'tcga_brca__data_clinical_sample') }}
