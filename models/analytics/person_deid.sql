-- Stage 4: HIPAA Safe Harbor over PERSON.
-- Drops the source identifier, keeps birth YEAR only, and caps ages over 89 by flooring the
-- birth year, per the Safe Harbor rule that ages above 89 must be aggregated.
-- The cap is computed from the current year rather than a literal, so it stays correct.
select
    person_id,
    gender_concept_id,
    case
        when year_of_birth is null then null
        when year(current_date) - year_of_birth > 89 then year(current_date) - 90
        else year_of_birth
    end as year_of_birth,
    race_concept_id,
    ethnicity_concept_id
from {{ ref('person') }}
