-- OMOP OBSERVATION — real-source clinical attributes that aren't measurements:
-- age at diagnosis, survival time, tumour stage (METABRIC), AJCC stage (TCGA),
-- vital status.
--
-- Both concepts come from the concept_map seed, so the file says what every column means:
--   observation_concept_id  what is being observed  (decision 9)
--   value_as_concept_id     what the answer is      (decisions 2, 5, 6)
--
-- Histologic grade lives in MEASUREMENT, not here: its concept, LOINC 44648-4, sits in the
-- Measurement domain, and OMOP routes a row by its concept's domain.
-- The raw string is always preserved in value_source_value.
with obs_concept as (
    select source, source_field, concept_id
    from {{ ref('concept_map') }}
    where omop_field = 'observation_concept_id' and review_status = 'STANDARD'
),
obs_unit as (
    select source, source_field, concept_id
    from {{ ref('concept_map') }}
    where omop_field = 'unit_concept_id' and omop_table = 'observation'
      and review_status = 'STANDARD'
),
value_map as (
    select source, source_field, source_value, concept_id
    from {{ ref('concept_map') }}
    where omop_field = 'value_as_concept_id'
      and omop_table = 'observation'
      and review_status = 'STANDARD'
      and nullif(source_value, '') is not null
),
attrs as (
    select 'metabric' as source, 'data_clinical_patient.AGE' as source_field,
           person_source_value, age_at_diagnosis as value_num,
           cast(null as varchar) as value_txt, 'Age at diagnosis' as label
    from {{ ref('stg_metabric__patient') }}
    union all
    select 'metabric', 'data_clinical_patient.VITAL_STATUS',
           person_source_value, null, vital_status, 'Vital status'
    from {{ ref('stg_metabric__patient') }}
    union all
    select 'metabric', 'data_clinical_sample.TUMOR_STAGE',
           person_source_value, try_to_double(tumor_stage), tumor_stage, 'Tumor stage'
    from {{ ref('stg_metabric__sample') }}
    union all
    -- Survival time. METABRIC has no dates, so DEATH stays empty (decision 1) and the
    -- interval is carried here instead. Deceased rows are survival; living rows are
    -- censored follow-up. Vital status separates them. Decision 10.
    select 'metabric', 'data_clinical_patient.OS_MONTHS',
           person_source_value, os_months, cast(null as varchar), 'Survival time'
    from {{ ref('stg_metabric__patient') }}
    union all
    select 'tcga_brca', 'data_clinical_patient.AJCC_PATHOLOGIC_TUMOR_STAGE',
           person_source_value, null, ajcc_stage, 'AJCC stage'
    from {{ ref('stg_tcga_brca__patient') }}
)
select
    row_number() over (order by a.person_source_value) as observation_id,
    p.person_id,
    coalesce(oc.concept_id, 0) as observation_concept_id,
    cast(null as date)         as observation_date,
    a.value_num                as value_as_number,
    vm.concept_id              as value_as_concept_id,
    a.value_txt                as value_source_value,
    ou.concept_id              as unit_concept_id,
    a.label                    as observation_source_value
from attrs a
join {{ ref('person') }} p on p.person_source_value = a.person_source_value
left join obs_concept oc
       on oc.source = a.source and oc.source_field = a.source_field
left join obs_unit ou
       on ou.source = a.source and ou.source_field = a.source_field
left join value_map vm
       on vm.source = a.source
      and vm.source_field = a.source_field
      and vm.source_value = a.value_txt
where a.value_num is not null or nullif(a.value_txt, '') is not null
