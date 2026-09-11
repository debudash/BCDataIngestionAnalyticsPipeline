-- OMOP OBSERVATION — real-source clinical attributes that aren't measurements:
-- age at diagnosis, tumor stage (METABRIC + TCGA AJCC), grade, vital status.
-- Concept resolution for these is a REVIEW item; the raw value is preserved in
-- value_source_value so nothing is lost before sign-off.
with concept as (
    select concept_id, vocabulary_id, concept_code, standard_concept
    from {{ source('omop_vocab', 'concept') }}
),
attrs as (
    select person_source_value, '30525-0' as loinc_code, age_at_diagnosis as value_num,
           cast(null as varchar) as value_txt, 'Age at diagnosis' as label
    from {{ ref('stg_metabric__patient') }}
    union all
    select person_source_value, null, null, vital_status, 'Vital status'
    from {{ ref('stg_metabric__patient') }}
    union all
    select person_source_value, null, null, tumor_stage, 'Tumor stage'
    from {{ ref('stg_metabric__sample') }}
    union all
    select person_source_value, null, try_to_double(grade), grade, 'Histologic grade'
    from {{ ref('stg_metabric__sample') }}
    union all
    select person_source_value, null, null, ajcc_stage, 'AJCC stage'
    from {{ ref('stg_tcga_brca__patient') }}
)
select
    row_number() over (order by a.person_source_value) as observation_id,
    p.person_id,
    coalesce(std.concept_id, 0) as observation_concept_id,
    cast(null as date)          as observation_date,
    a.value_num                 as value_as_number,
    cast(null as integer)       as value_as_concept_id,
    a.value_txt                 as value_source_value,
    a.label                     as observation_source_value
from attrs a
join {{ ref('person') }} p on p.person_source_value = a.person_source_value
left join concept std on std.vocabulary_id = 'LOINC' and std.concept_code = a.loinc_code
where a.value_num is not null or nullif(a.value_txt, '') is not null
