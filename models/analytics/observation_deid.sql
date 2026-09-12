-- Stage 4: Safe Harbor over OBSERVATION.
-- Year only for the date; concepts, values and units retained as clinical facts.
-- Survival time stays in months: it is an interval, not a date tied to a calendar, so
-- Safe Harbor's date rule does not reach it.
select
    observation_id,
    person_id,
    observation_concept_id,
    year(observation_date) as observation_year,
    value_as_number,
    value_as_concept_id,
    value_source_value,
    unit_concept_id,
    observation_source_value
from {{ ref('observation') }}
