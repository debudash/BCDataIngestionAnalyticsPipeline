-- OMOP DEATH. One row per patient with a death date.
select
    p.person_id,
    pat.death_date,
    32817 as death_type_concept_id   -- 'EHR' (OMOP Type Concept)
from {{ ref('stg_synthea__patients') }} pat
join {{ ref('person') }} p
     on p.person_source_value = pat.person_source_value
where pat.death_date is not null
