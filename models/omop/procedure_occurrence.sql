-- OMOP PROCEDURE_OCCURRENCE. Synthea only, for the same reason as DRUG_EXPOSURE: neither
-- METABRIC nor TCGA-BRCA ships treatment records. This is what makes the synthetic arm worth
-- having — surgery, biopsy and radiotherapy exist nowhere else in the cohort.
--
-- Synthea codes procedures in SNOMED, so the concept resolves by joining the Athena
-- vocabulary on (vocabulary_id, concept_code). No human mapping decision is needed.
with concept as (
    select concept_id, vocabulary_id, concept_code, standard_concept
    from {{ source('omop_vocab', 'concept') }}
)
select
    row_number() over (order by p2.procedure_date nulls last) as procedure_occurrence_id,
    p.person_id,
    coalesce(std.concept_id, 0) as procedure_concept_id,
    p2.procedure_date,
    p2.procedure_source_value,
    p2.snomed_code
from {{ ref('stg_synthea__procedures') }} p2
join {{ ref('person') }} p on p.person_source_value = p2.person_source_value
left join concept std
       on std.vocabulary_id = 'SNOMED'
      and std.concept_code = p2.snomed_code
      and std.standard_concept = 'S'
