-- Stage 4: Safe Harbor over MEASUREMENT.
-- Year only for the date. Concept ids, numeric values and units are clinical facts, not
-- identifiers, so they stay: stripping them would leave nothing to analyse.
-- value_source_value is kept because it carries the answer for rows that never resolved to a
-- value concept (the NA receptor and grade results); it holds clinical text, never an id.
select
    measurement_id,
    person_id,
    measurement_concept_id,
    year(measurement_date) as measurement_year,
    value_as_number,
    value_as_concept_id,
    value_source_value,
    unit_concept_id,
    measurement_source_value
from {{ ref('measurement') }}
