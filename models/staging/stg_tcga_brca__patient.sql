-- TCGA-BRCA patient-level clinical (cBioPortal data_clinical_patient.txt).
-- Column names follow concept_map.csv; verify against the real header and fix here.
select
    "PATIENT_ID"                        as person_source_value,
    case upper("SEX")
        when 'FEMALE' then 'F' when 'F' then 'F'
        when 'MALE'   then 'M' when 'M' then 'M'
    end                                 as gender_source_value,
    "AJCC_PATHOLOGIC_TUMOR_STAGE"       as ajcc_stage
from {{ source('raw', 'tcga_brca__data_clinical_patient') }}
