-- Crosswalk linking a genomic sample to an OMOP person, so genomic rows can be
-- analyzed at the cohort level. Populates as clinical person models for the real
-- sources are added (today PERSON is built from Synthea).
select
    s."SAMPLE_ID"   as sample_id,
    s."PATIENT_ID"  as patient_id,
    p.person_id
from {{ source('raw', 'metabric__data_clinical_sample') }} s
left join {{ ref('person') }} p
       on p.person_source_value = s."PATIENT_ID"
