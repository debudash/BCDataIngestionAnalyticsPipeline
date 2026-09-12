{#-
  Completeness reconciliation across RAW -> OMOP -> ANALYTICS for every source.

  Answers three questions in one result set:
    1. person  — did every downloaded patient become an OMOP person? (delta should be 0)
    2. mapping — how many rows resolved to a real concept vs concept_id = 0 (unmapped)?
    3. total   — headline row counts for the key output tables.

  Analyses are COMPILED, not executed by `dbt build`, so this never affects your data.
  Run it:
     dbt compile --select reconciliation
     # then run target/compiled/breast_cancer_omop/analyses/reconciliation.sql in Snowflake
  Pair it with the INFORMATION_SCHEMA.TABLES query in the README to confirm every model
  materialized and every downloaded file produced a RAW table.
-#}

with raw_patients as (
    select 'synthea' as source, count(distinct "Id") as n
    from {{ source('raw', 'synthea__patients') }}
    union all
    select 'metabric', count(distinct "PATIENT_ID")
    from {{ source('raw', 'metabric__data_clinical_patient') }}
    union all
    select 'tcga_brca', count(distinct "PATIENT_ID")
    from {{ source('raw', 'tcga_brca__data_clinical_patient') }}
),

-- Attribute each OMOP person back to its source by matching the source identifier.
person_by_source as (
    select
        case
            when person_source_value in (select "Id" from {{ source('raw', 'synthea__patients') }})
                 then 'synthea'
            when person_source_value in (select "PATIENT_ID" from {{ source('raw', 'metabric__data_clinical_patient') }})
                 then 'metabric'
            when person_source_value in (select "PATIENT_ID" from {{ source('raw', 'tcga_brca__data_clinical_patient') }})
                 then 'tcga_brca'
            else 'UNATTRIBUTED'
        end as source,
        count(*) as n
    from {{ ref('person') }}
    group by 1
),

report as (

    -- 1. Person reconciliation: raw distinct patients vs OMOP persons, per source.
    select 1 as sort, 'person' as check_group, r.source as item,
           r.n                          as source_count,
           coalesce(p.n, 0)             as modeled_count,
           r.n - coalesce(p.n, 0)       as delta,
           'raw distinct patients vs OMOP persons; delta should be 0' as note
    from raw_patients r
    left join person_by_source p on p.source = r.source

    -- 2. Mapping coverage: total rows vs how many resolved to a real concept_id.
    union all
    select 2, 'mapping', 'condition_occurrence',
           count(*), sum(iff(condition_concept_id <> 0, 1, 0)),
           sum(iff(condition_concept_id = 0, 1, 0)),
           'delta = unmapped (concept_id 0)'
    from {{ ref('condition_occurrence') }}
    union all
    select 2, 'mapping', 'measurement',
           count(*), sum(iff(measurement_concept_id <> 0, 1, 0)),
           sum(iff(measurement_concept_id = 0, 1, 0)),
           'delta = unmapped; expect ~15k Synthea QALY/DALY/QOLS (no LOINC)'
    from {{ ref('measurement') }}
    union all
    select 2, 'mapping', 'observation',
           count(*), sum(iff(observation_concept_id <> 0, 1, 0)),
           sum(iff(observation_concept_id = 0, 1, 0)),
           'delta = unmapped (concept_id 0)'
    from {{ ref('observation') }}

    -- 3. Totals: headline counts (no per-source split / delta).
    union all
    select 3, 'total', 'OMOP.PERSON',
           cast(null as number), count(*), cast(null as number), 'all sources combined'
    from {{ ref('person') }}
    union all
    select 3, 'total', 'GENOMIC.SAMPLE_PERSON',
           cast(null as number), count(*), cast(null as number),
           'genomic samples linked to a person'
    from {{ ref('sample_person') }}
    union all
    select 3, 'total', 'ANALYTICS.UNIQUE_PATIENTS',
           cast(null as number), count(*), cast(null as number),
           'de-identified roster; should equal OMOP.PERSON'
    from {{ ref('unique_patients') }}
)

select check_group, item, source_count, modeled_count, delta, note
from report
order by sort, item
