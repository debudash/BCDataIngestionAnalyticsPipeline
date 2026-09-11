-- OMOP CONDITION_OCCURRENCE across sources.
--  * Synthea: SNOMED-coded condition events, resolved via the Athena CONCEPT vocabulary.
--  * METABRIC / TCGA: one breast-cancer diagnosis per sample, using the fixed concept the
--    concept_map seed assigns to CANCER_TYPE_DETAILED (SNOMED 254837009 -> concept 4112853).
with concept as (
    select concept_id, vocabulary_id, concept_code, standard_concept
    from {{ source('omop_vocab', 'concept') }}
),
cancer_concept as (
    select max(concept_id) as concept_id from {{ ref('concept_map') }}
    where source_field like '%CANCER_TYPE_DETAILED%' and concept_id is not null
),
synthea as (
    select p.person_id,
           coalesce(std.concept_id, 0) as condition_concept_id,
           c.condition_start_date,
           c.condition_source_value,
           c.snomed_code as source_code
    from {{ ref('stg_synthea__conditions') }} c
    join {{ ref('person') }} p on p.person_source_value = c.person_source_value
    left join concept std
           on std.vocabulary_id = 'SNOMED' and std.concept_code = c.snomed_code
          and std.standard_concept = 'S'
),
real_dx as (
    select p.person_id,
           (select concept_id from cancer_concept) as condition_concept_id,
           cast(null as date) as condition_start_date,
           s.cancer_type_detailed as condition_source_value,
           '254837009' as source_code
    from (
        select person_source_value, cancer_type_detailed from {{ ref('stg_metabric__sample') }}
        union all
        select person_source_value, cancer_type_detailed from {{ ref('stg_tcga_brca__sample') }}
    ) s
    join {{ ref('person') }} p on p.person_source_value = s.person_source_value
),
combined as (
    select * from synthea
    union all
    select * from real_dx
)
select
    row_number() over (order by condition_start_date nulls last) as condition_occurrence_id,
    person_id, condition_concept_id, condition_start_date,
    condition_source_value, source_code as snomed_code
from combined
