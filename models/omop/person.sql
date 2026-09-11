-- OMOP PERSON — unified across all three sources. Demographics use the value-map style:
-- join the reviewed concept_map seed to turn source strings into standard concept_ids.
-- Synthea carries gender/race/ethnicity; the real sources carry gender only (others -> 0).
with sources as (
    select person_source_value, gender_source_value, race_source_value,
           ethnicity_source_value, birth_date
    from {{ ref('stg_synthea__patients') }}
    union all
    select person_source_value, gender_source_value, null, null, null
    from {{ ref('stg_metabric__patient') }}
    union all
    select person_source_value, gender_source_value, null, null, null
    from {{ ref('stg_tcga_brca__patient') }}
),
gender as (
    select distinct source_value, concept_id from {{ ref('concept_map') }}
    where omop_field = 'gender_concept_id' and nullif(source_value, '') is not null
),
race as (
    select source_value, concept_id from {{ ref('concept_map') }}
    where source_field = 'patients.RACE'
),
ethnicity as (
    select source_value, concept_id from {{ ref('concept_map') }}
    where source_field = 'patients.ETHNICITY'
)
select
    row_number() over (order by s.person_source_value) as person_id,
    coalesce(g.concept_id, 0)   as gender_concept_id,
    year(s.birth_date)          as year_of_birth,
    s.birth_date                as birth_datetime,
    coalesce(r.concept_id, 0)   as race_concept_id,
    coalesce(e.concept_id, 0)   as ethnicity_concept_id,
    s.person_source_value,
    s.gender_source_value
from sources s
left join gender     g on g.source_value = s.gender_source_value
left join race       r on r.source_value = s.race_source_value
left join ethnicity  e on e.source_value = s.ethnicity_source_value
