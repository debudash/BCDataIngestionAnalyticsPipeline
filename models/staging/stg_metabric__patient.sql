-- METABRIC patient-level clinical (cBioPortal data_clinical_patient.txt).
-- NOTE: column names follow concept_map.csv; verify against the actual file header and
-- adjust HERE if they differ — downstream OMOP models depend only on these aliases.
-- METABRIC is a female breast-cancer cohort, so gender is fixed to 'F' (no SEX column).
select
    "PATIENT_ID"                    as person_source_value,
    'F'                             as gender_source_value,
    try_to_double("AGE_AT_DIAGNOSIS") as age_at_diagnosis,
    "VITAL_STATUS"                  as vital_status,
    "OS_STATUS"                     as os_status,
    try_to_double("OS_MONTHS")      as os_months
from {{ source('raw', 'metabric__data_clinical_patient') }}
