-- Stage 4 output: the de-identified unique-patient roster, one row per person, built only
-- from the de-identified models so nothing identifying can reach it by accident.
-- Counts rather than raw rows: this is the entry point analysts start from before drilling
-- into the per-fact de-identified tables.
select
    p.person_id,
    p.gender_concept_id,
    p.year_of_birth,
    count(distinct c.condition_concept_id) as distinct_conditions,
    count(distinct m.hugo_symbol)          as distinct_mutated_genes
from {{ ref('person_deid') }} p
left join {{ ref('condition_occurrence_deid') }} c on c.person_id = p.person_id
left join {{ ref('mutations_deid') }} m            on m.person_id = p.person_id
group by 1, 2, 3
