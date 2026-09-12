-- Crosswalk linking a genomic sample to an OMOP person, so mutation rows can be analysed at
-- the cohort level. Both real sources are covered: the mutation files key on the sample
-- barcode, while PERSON keys on the patient identifier, and only the clinical sample file
-- carries both.
--
-- Reads the staging views rather than RAW so the column names are cleaned in one place.
with samples as (
    select 'metabric' as source, sample_id, person_source_value
    from {{ ref('stg_metabric__sample') }}
    union all
    select 'tcga_brca', sample_id, person_source_value
    from {{ ref('stg_tcga_brca__sample') }}
)
select
    s.source,
    s.sample_id,
    s.person_source_value as patient_id,
    p.person_id
from samples s
left join {{ ref('person') }} p
       on p.person_source_value = s.person_source_value
