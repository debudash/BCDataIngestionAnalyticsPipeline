-- OMOP MEASUREMENT across sources.
--  * Synthea: numeric observations (LOINC), resolved via the vocabulary.
--  * METABRIC / TCGA: receptor status (ER/PR/HER2) and tumour size as measurements. The
--    LOINC code per attribute comes from the concept_map seed.
--
-- Decision 4: Positive / Negative now resolve to SNOMED qualifier values in
-- value_as_concept_id. NA and blank stay unmapped rather than guessed, and the raw string
-- stays in value_source_value so the assay can still be told apart.
-- Decision 8: tumour size carries its UCUM unit concept (millimetre) from the seed.
-- Decision 9: histologic grade moved here from OBSERVATION, because its concept sits
-- in the Measurement domain and OMOP routes a row by its concept's domain.
with concept as (
    select concept_id, vocabulary_id, concept_code, standard_concept
    from {{ source('omop_vocab', 'concept') }}
),
value_map as (
    select source, source_field, source_value, concept_id
    from {{ ref('concept_map') }}
    where omop_field = 'value_as_concept_id'
      and omop_table = 'measurement'
      and review_status = 'STANDARD'
      and nullif(source_value, '') is not null
),
unit_map as (
    select source_code, concept_id
    from {{ ref('concept_map') }}
    where omop_field = 'unit_concept_id' and review_status = 'STANDARD'
),
synthea as (
    select p.person_id,
           coalesce(std.concept_id, 0) as measurement_concept_id,
           o.measurement_date,
           o.value_as_number,
           cast(null as integer)  as value_as_concept_id,
           cast(null as varchar)  as value_source_value,
           o.unit_source_value,
           cast(null as integer)  as unit_concept_id,
           o.measurement_source_value
    from {{ ref('stg_synthea__observations') }} o
    join {{ ref('person') }} p on p.person_source_value = o.person_source_value
    left join concept std on std.vocabulary_id = 'LOINC' and std.concept_code = o.loinc_code
),
-- Unpivot the real-source attributes into (loinc_code, value_number, value_text) rows.
real_attrs as (
    select person_source_value, 'data_clinical_sample.ER_STATUS' as source_field,
           '85337-4' as loinc_code, cast(null as double) as value_num,
           er_status as value_txt, 'ER status' as label from {{ ref('stg_metabric__sample') }}
    union all
    select person_source_value, 'data_clinical_sample.PR_STATUS', '85339-0', null,
           pr_status, 'PR status' from {{ ref('stg_metabric__sample') }}
    union all
    select person_source_value, 'data_clinical_sample.HER2_STATUS', '48676-1', null,
           her2_status, 'HER2 status' from {{ ref('stg_metabric__sample') }}
    union all
    select person_source_value, 'data_clinical_sample.TUMOR_SIZE', '21889-1', tumor_size_mm,
           null, 'Tumor size' from {{ ref('stg_metabric__sample') }}
    union all
    -- LOINC 44648-4 is histologic grade in a BREAST cancer specimen by Nottingham, which is
    -- the same scale as the grade 1/2/3 value concepts. Decision 9.
    select person_source_value, 'data_clinical_sample.GRADE', '44648-4', try_to_double(grade),
           grade, 'Histologic grade' from {{ ref('stg_metabric__sample') }}
),
real_meas as (
    select p.person_id,
           coalesce(std.concept_id, 0) as measurement_concept_id,
           cast(null as date) as measurement_date,
           a.value_num as value_as_number,
           vm.concept_id as value_as_concept_id,
           a.value_txt as value_source_value,
           case when a.loinc_code = '21889-1' then 'mm' end as unit_source_value,
           case when a.loinc_code = '21889-1' then um.concept_id end as unit_concept_id,
           a.label as measurement_source_value
    from real_attrs a
    join {{ ref('person') }} p on p.person_source_value = a.person_source_value
    left join concept std on std.vocabulary_id = 'LOINC' and std.concept_code = a.loinc_code
    left join value_map vm
           on vm.source = 'metabric'
          and vm.source_field = a.source_field
          and vm.source_value = a.value_txt
    left join unit_map um on um.source_code = 'mm'
    where a.value_num is not null or nullif(a.value_txt, '') is not null
)
select
    row_number() over (order by measurement_date nulls last) as measurement_id,
    person_id, measurement_concept_id, measurement_date, value_as_number,
    value_as_concept_id, value_source_value, unit_source_value, unit_concept_id,
    measurement_source_value
from (
    select * from synthea
    union all
    select * from real_meas
)
