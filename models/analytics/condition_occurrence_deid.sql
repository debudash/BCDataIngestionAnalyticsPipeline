-- Stage 4: shift dates by a consistent offset (set var date_shift_days > 0 to demonstrate)
-- and drop free-text source values.
select
    condition_occurrence_id,
    person_id,
    condition_concept_id,
    dateadd(day, -{{ var('date_shift_days', 0) }}, condition_start_date) as condition_start_date
from {{ ref('condition_occurrence') }}
