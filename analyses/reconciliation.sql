{#-
  Completeness reconciliation across RAW -> OMOP -> ANALYTICS for every source.

  Answers four questions in one result set:
    1. person   — did every downloaded patient become an OMOP person? (delta must be 0)
    2. mapping  — how many rows resolved to a real concept vs concept_id = 0?
    3. deid     — does every OMOP fact table have a de-identified counterpart of equal size?
    4. total    — headline counts for the key output tables.

  Every check states what the delta SHOULD be. A check whose note only says "delta =
  unmapped" cannot tell you whether the number is fine, which is how 8,077 unmapped
  observations went unexplained for a while.

  Analyses are COMPILED, not executed by `dbt build`, so this never affects your data.
  Run it:
     dbt compile --select reconciliation
     # then run target/compiled/breast_cancer_omop/analyses/reconciliation.sql in Snowflake
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
           r.n                    as source_count,
           coalesce(p.n, 0)       as modeled_count,
           r.n - coalesce(p.n, 0) as delta,
           'raw distinct patients vs OMOP persons; delta must be 0' as note
    from raw_patients r
    left join person_by_source p on p.source = r.source

    -- 2. Mapping coverage: total rows vs how many resolved to a real concept_id.
    union all
    select 2, 'mapping', 'condition_occurrence',
           count(*), sum(iff(condition_concept_id <> 0, 1, 0)),
           sum(iff(condition_concept_id = 0, 1, 0)),
           'delta must be 0; the concept-map review mapped every histology'
    from {{ ref('condition_occurrence') }}
    union all
    select 2, 'mapping', 'observation',
           count(*), sum(iff(observation_concept_id <> 0, 1, 0)),
           sum(iff(observation_concept_id = 0, 1, 0)),
           'delta must be 0; every observation type was given a concept in the review'
    from {{ ref('observation') }}
    union all
    select 2, 'mapping', 'drug_exposure',
           count(*), sum(iff(drug_concept_id <> 0, 1, 0)),
           sum(iff(drug_concept_id = 0, 1, 0)),
           'delta must be 0; Synthea emits RxNorm the vocabulary already knows'
    from {{ ref('drug_exposure') }}
    union all
    select 2, 'mapping', 'procedure_occurrence',
           count(*), sum(iff(procedure_concept_id <> 0, 1, 0)),
           sum(iff(procedure_concept_id = 0, 1, 0)),
           'delta = SNOMED procedure codes absent from the loaded vocabulary'
    from {{ ref('procedure_occurrence') }}
    union all
    select 2, 'mapping', 'measurement',
           count(*), sum(iff(measurement_concept_id <> 0, 1, 0)),
           sum(iff(measurement_concept_id = 0, 1, 0)),
           'delta = Synthea QALY/DALY/QOLS only; no LOINC equivalent exists'
    from {{ ref('measurement') }}

    -- 3. De-identification coverage: every fact table must reach ANALYTICS intact.
    union all
    select 3, 'deid', 'person',
           (select count(*) from {{ ref('person') }}),
           (select count(*) from {{ ref('person_deid') }}),
           (select count(*) from {{ ref('person') }})
             - (select count(*) from {{ ref('person_deid') }}),
           'OMOP vs de-identified row count; delta must be 0'
    union all
    select 3, 'deid', 'condition_occurrence',
           (select count(*) from {{ ref('condition_occurrence') }}),
           (select count(*) from {{ ref('condition_occurrence_deid') }}),
           (select count(*) from {{ ref('condition_occurrence') }})
             - (select count(*) from {{ ref('condition_occurrence_deid') }}),
           'OMOP vs de-identified row count; delta must be 0'
    union all
    select 3, 'deid', 'measurement',
           (select count(*) from {{ ref('measurement') }}),
           (select count(*) from {{ ref('measurement_deid') }}),
           (select count(*) from {{ ref('measurement') }})
             - (select count(*) from {{ ref('measurement_deid') }}),
           'OMOP vs de-identified row count; delta must be 0'
    union all
    select 3, 'deid', 'observation',
           (select count(*) from {{ ref('observation') }}),
           (select count(*) from {{ ref('observation_deid') }}),
           (select count(*) from {{ ref('observation') }})
             - (select count(*) from {{ ref('observation_deid') }}),
           'OMOP vs de-identified row count; delta must be 0'
    union all
    select 3, 'deid', 'visit_occurrence',
           (select count(*) from {{ ref('visit_occurrence') }}),
           (select count(*) from {{ ref('visit_occurrence_deid') }}),
           (select count(*) from {{ ref('visit_occurrence') }})
             - (select count(*) from {{ ref('visit_occurrence_deid') }}),
           'OMOP vs de-identified row count; delta must be 0'
    union all
    select 3, 'deid', 'drug_exposure',
           (select count(*) from {{ ref('drug_exposure') }}),
           (select count(*) from {{ ref('drug_exposure_deid') }}),
           (select count(*) from {{ ref('drug_exposure') }})
             - (select count(*) from {{ ref('drug_exposure_deid') }}),
           'OMOP vs de-identified row count; delta must be 0'
    union all
    select 3, 'deid', 'procedure_occurrence',
           (select count(*) from {{ ref('procedure_occurrence') }}),
           (select count(*) from {{ ref('procedure_occurrence_deid') }}),
           (select count(*) from {{ ref('procedure_occurrence') }})
             - (select count(*) from {{ ref('procedure_occurrence_deid') }}),
           'OMOP vs de-identified row count; delta must be 0'
    union all
    select 3, 'deid', 'observation_period',
           (select count(*) from {{ ref('observation_period') }}),
           (select count(*) from {{ ref('observation_period_deid') }}),
           (select count(*) from {{ ref('observation_period') }})
             - (select count(*) from {{ ref('observation_period_deid') }}),
           'OMOP vs de-identified row count; delta must be 0'
    union all
    select 3, 'deid', 'mutations',
           (select count(*) from {{ ref('metabric_mutations') }})
             + (select count(*) from {{ ref('tcga_brca_mutations') }}),
           (select count(*) from {{ ref('mutations_deid') }}),
           (select count(*) from {{ ref('metabric_mutations') }})
             + (select count(*) from {{ ref('tcga_brca_mutations') }})
             - (select count(*) from {{ ref('mutations_deid') }}),
           'delta = mutations whose sample never resolved to a person; must be 0'

    -- 3b. OHDSI readiness: a person with no observation period is invisible to ATLAS,
    --     Achilles and the DQD, however complete their clinical data looks.
    union all
    select 3, 'ohdsi', 'observation_period coverage',
           (select count(*) from {{ ref('person') }}),
           (select count(*) from {{ ref('observation_period') }}),
           (select count(*) from {{ ref('person') }})
             - (select count(*) from {{ ref('observation_period') }}),
           'delta = persons OHDSI tools cannot see; expected 3,593 dateless METABRIC + TCGA'

    -- 4. Totals: headline counts (no per-source split / delta).
    union all
    select 4, 'total', 'OMOP.PERSON',
           cast(null as number), count(*), cast(null as number), 'all sources combined'
    from {{ ref('person') }}
    union all
    select 4, 'total', 'GENOMIC.SAMPLE_PERSON',
           cast(null as number), count(*), cast(null as number),
           'genomic samples linked to a person'
    from {{ ref('sample_person') }}
    union all
    select 4, 'total', 'ANALYTICS.UNIQUE_PATIENTS',
           cast(null as number), count(*), cast(null as number),
           'de-identified roster; must equal OMOP.PERSON'
    from {{ ref('unique_patients') }}
)

select check_group, item, source_count, modeled_count, delta, note
from report
order by sort, item
