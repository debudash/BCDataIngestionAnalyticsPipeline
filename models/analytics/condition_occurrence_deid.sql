-- Stage 4: Safe Harbor over CONDITION_OCCURRENCE.
-- Safe Harbor allows the YEAR of a date tied to an individual and nothing finer, so the full
-- date is truncated rather than shifted. A consistent per-patient shift would preserve
-- intervals but is a Limited Data Set, a different legal basis requiring a data use agreement.
-- The free-text source value is dropped; condition_concept_id already carries the histology.
select
    condition_occurrence_id,
    person_id,
    condition_concept_id,
    year(condition_start_date) as condition_start_year
from {{ ref('condition_occurrence') }}
