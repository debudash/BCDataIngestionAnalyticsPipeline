-- OMOP OBSERVATION — real-source clinical attributes that aren't measurements:
-- age at diagnosis, tumour stage (METABRIC + TCGA AJCC), histologic grade, vital status.
--
-- Approved value mappings come from the concept_map seed and land in value_as_concept_id:
--   vital status  -> SNOMED Alive / Dead        (decision 2)
--   grade         -> Nottingham grade 1/2/3     (decision 7)
--   AJCC stage    -> AJCC 7th pathological      (decision 6; STAGE X stays unmapped)
-- METABRIC's TUMOR_STAGE is still REVIEW (decision 5): bare integers with no stated AJCC
-- edition, so the number is kept in value_as_number and no concept is asserted.
-- The raw string is always preserved in value_source_value.
with concept as (
    select concept_id, vocabulary_id, concept_code, standard_concept
    from {{ source('omop_vocab', 'concept') }}
),
value_map as (
    select source, source_field, source_value, concept_id
    from {{ ref('concept_map') }}
    where omop_field = 'value_as_concept_id'
      and review_status = 'STANDARD'
      and nullif(source_value, '') is not null
),
attrs as (
    select 'metabric' as source, 'data_clinical_patient.AGE' as source_field,
           person_source_value, '30525-0' as loinc_code, age_at_diagnosis as value_num,
           cast(null as varchar) as value_txt, 'Age at diagnosis' as label
    from {{ ref('stg_metabric__patient') }}
    union all
    select 'metabric', 'data_clinical_patient.VITAL_STATUS',
           person_source_value, null, null, vital_status, 'Vital status'
    from {{ ref('stg_metabric__patient') }}
    union all
    select 'metabric', 'data_clinical_sample.TUMOR_STAGE',
           person_source_value, null, try_to_double(tumor_stage), tumor_stage, 'Tumor stage'
    from {{ ref('stg_metabric__sample') }}
    union all
    select 'metabric', 'data_clinical_sample.GRADE',
           person_source_value, null, try_to_double(grade), grade, 'Histologic grade'
    from {{ ref('stg_metabric__sample') }}
    union all
    select 'tcga_brca', 'data_clinical_patient.AJCC_PATHOLOGIC_TUMOR_STAGE',
           person_source_value, null, null, ajcc_stage, 'AJCC stage'
    from {{ ref('stg_tcga_brca__patient') }}
)
select
    row_number() over (order by a.person_source_value) as observation_id,
    p.person_id,
    coalesce(std.concept_id, 0) as observation_concept_id,
    cast(null as date)          as observation_date,
    a.value_num                 as value_as_number,
    vm.concept_id               as value_as_concept_id,
    a.value_txt                 as value_source_value,
    a.label                     as observation_source_value
from attrs a
join {{ ref('person') }} p on p.person_source_value = a.person_source_value
left join concept std on std.vocabulary_id = 'LOINC' and std.concept_code = a.loinc_code
left join value_map vm
       on vm.source = a.source
      and vm.source_field = a.source_field
      and vm.source_value = a.value_txt
where a.value_num is not null or nullif(a.value_txt, '') is not null
