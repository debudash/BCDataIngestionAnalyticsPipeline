-- Stage 4: HIPAA Safe Harbor over PERSON. Drop source identifiers, keep birth YEAR only,
-- cap ages > 89 (Safe Harbor rule). Sources are already synthetic — this demonstrates the method.
select
    person_id,
    gender_concept_id,
    case when (2026 - year_of_birth) > 89 then 2026 - 90 else year_of_birth end as year_of_birth,
    race_concept_id,
    ethnicity_concept_id
from {{ ref('person') }}
