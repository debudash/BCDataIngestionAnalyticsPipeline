-- OMOP VISIT_OCCURRENCE. Map Synthea encounter class to standard visit concepts.
with enc as (
    select * from {{ ref('stg_synthea__encounters') }}
)
select
    row_number() over (order by e.visit_start_date) as visit_occurrence_id,
    p.person_id,
    case lower(e.encounter_class)
        when 'inpatient'  then 9201
        when 'emergency'  then 9203
        when 'ambulatory' then 9202
        when 'outpatient' then 9202
        when 'wellness'   then 9202
        else 0
    end as visit_concept_id,
    e.visit_start_date,
    e.visit_end_date,
    e.encounter_class as visit_source_value
from enc e
join {{ ref('person') }} p
     on p.person_source_value = e.person_source_value
