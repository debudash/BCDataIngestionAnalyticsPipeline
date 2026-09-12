-- OMOP DRUG_EXPOSURE. Synthea only: neither METABRIC nor TCGA-BRCA ships treatment records,
-- so this table is single-source by nature rather than by omission.
--
-- Synthea codes medications in RxNorm, so the drug concept resolves the same way Synthea's
-- conditions and observations do: join the Athena vocabulary on (vocabulary_id, concept_code).
-- The concept_map marks this RESOLVE_AT_ETL, meaning no human mapping decision is needed.
with concept as (
    select concept_id, vocabulary_id, concept_code, standard_concept
    from {{ source('omop_vocab', 'concept') }}
)
select
    row_number() over (order by m.drug_exposure_start_date nulls last) as drug_exposure_id,
    p.person_id,
    coalesce(std.concept_id, 0) as drug_concept_id,
    m.drug_exposure_start_date,
    m.drug_exposure_end_date,
    m.dispenses as quantity,
    m.drug_source_value,
    m.rxnorm_code
from {{ ref('stg_synthea__medications') }} m
join {{ ref('person') }} p on p.person_source_value = m.person_source_value
left join concept std
       on std.vocabulary_id = 'RxNorm'
      and std.concept_code = m.rxnorm_code
      and std.standard_concept = 'S'
