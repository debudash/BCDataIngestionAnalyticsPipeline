-- OMOP CONDITION_OCCURRENCE across sources.
--  * Synthea: SNOMED-coded condition events, resolved via the Athena CONCEPT vocabulary.
--  * METABRIC / TCGA: one diagnosis per sample. CANCER_TYPE_DETAILED is matched against the
--    concept_map seed (decision 3), so ductal, lobular, mixed and mucinous each land on their
--    own SNOMED disorder instead of a single generic breast-cancer concept. Both studies use
--    the same wording, so one set of seed rows per source covers them.
with concept as (
    select concept_id, vocabulary_id, concept_code, standard_concept
    from {{ source('omop_vocab', 'concept') }}
),
histology as (
    select source, source_value, concept_id
    from {{ ref('concept_map') }}
    where omop_field = 'condition_concept_id'
      and review_status = 'STANDARD'
      and nullif(source_value, '') is not null
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
           coalesce(h.concept_id, 0) as condition_concept_id,
           cast(null as date)        as condition_start_date,
           s.cancer_type_detailed    as condition_source_value,
           cast(null as varchar)     as source_code
    from (
        select 'metabric'  as source, person_source_value, cancer_type_detailed
        from {{ ref('stg_metabric__sample') }}
        union all
        select 'tcga_brca', person_source_value, cancer_type_detailed
        from {{ ref('stg_tcga_brca__sample') }}
    ) s
    join {{ ref('person') }} p on p.person_source_value = s.person_source_value
    left join histology h
           on h.source = s.source and h.source_value = s.cancer_type_detailed
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
