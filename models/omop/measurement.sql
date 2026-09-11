-- OMOP MEASUREMENT across sources.
--  * Synthea: numeric observations (LOINC), resolved via the vocabulary.
--  * METABRIC / TCGA: receptor status (ER/PR/HER2) and tumor size as measurements. The
--    LOINC code per attribute comes from the concept_map seed. Positive/Negative -> a
--    standard value_as_concept_id is a REVIEW item, so the status is kept in
--    value_source_value and value_as_concept_id is left null pending sign-off.
with concept as (
    select concept_id, vocabulary_id, concept_code, standard_concept
    from {{ source('omop_vocab', 'concept') }}
),
synthea as (
    select p.person_id,
           coalesce(std.concept_id, 0) as measurement_concept_id,
           o.measurement_date,
           o.value_as_number,
           cast(null as integer)  as value_as_concept_id,
           cast(null as varchar)  as value_source_value,
           o.unit_source_value,
           o.measurement_source_value
    from {{ ref('stg_synthea__observations') }} o
    join {{ ref('person') }} p on p.person_source_value = o.person_source_value
    left join concept std on std.vocabulary_id = 'LOINC' and std.concept_code = o.loinc_code
),
-- Unpivot the real-source attributes into (loinc_code, value_number, value_text) rows.
real_attrs as (
    select person_source_value, '85337-4' as loinc_code, cast(null as double) as value_num,
           er_status as value_txt, 'ER status' as label from {{ ref('stg_metabric__sample') }}
    union all
    select person_source_value, '85339-0', null, pr_status, 'PR status' from {{ ref('stg_metabric__sample') }}
    union all
    select person_source_value, '48676-1', null, her2_status, 'HER2 status' from {{ ref('stg_metabric__sample') }}
    union all
    select person_source_value, '21889-1', tumor_size_mm, null, 'Tumor size' from {{ ref('stg_metabric__sample') }}
    union all
    select person_source_value, '85337-4', null, er_status, 'ER status by IHC' from {{ ref('stg_tcga_brca__sample') }}
),
real_meas as (
    select p.person_id,
           coalesce(std.concept_id, 0) as measurement_concept_id,
           cast(null as date) as measurement_date,
           a.value_num as value_as_number,
           cast(null as integer) as value_as_concept_id,
           a.value_txt as value_source_value,
           case when a.loinc_code = '21889-1' then 'mm' end as unit_source_value,
           a.label as measurement_source_value
    from real_attrs a
    join {{ ref('person') }} p on p.person_source_value = a.person_source_value
    left join concept std on std.vocabulary_id = 'LOINC' and std.concept_code = a.loinc_code
    where a.value_num is not null or nullif(a.value_txt, '') is not null
)
select
    row_number() over (order by measurement_date nulls last) as measurement_id,
    person_id, measurement_concept_id, measurement_date, value_as_number,
    value_as_concept_id, value_source_value, unit_source_value, measurement_source_value
from (
    select * from synthea
    union all
    select * from real_meas
)
