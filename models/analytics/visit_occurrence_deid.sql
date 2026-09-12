-- Stage 4: Safe Harbor over VISIT_OCCURRENCE.
-- Both dates truncate to year. That loses length of stay, which is why a Limited Data Set is
-- the usual choice when utilisation analysis matters; under Safe Harbor it cannot be kept.
select
    visit_occurrence_id,
    person_id,
    visit_concept_id,
    year(visit_start_date) as visit_start_year,
    year(visit_end_date)   as visit_end_year
from {{ ref('visit_occurrence') }}
