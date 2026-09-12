-- Stage 4: Safe Harbor over OBSERVATION_PERIOD. Both bounds truncate to year, which loses the
-- exact follow-up length. That is the cost of Safe Harbor: OHDSI tools run against the OMOP
-- schema, while this layer serves year-level cohort analysis.
select
    observation_period_id,
    person_id,
    year(observation_period_start_date) as observation_period_start_year,
    year(observation_period_end_date)   as observation_period_end_year,
    period_type_concept_id
from {{ ref('observation_period') }}
