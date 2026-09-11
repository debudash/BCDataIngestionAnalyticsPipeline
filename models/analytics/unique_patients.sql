-- Stage 4 output: the de-identified unique-patient roster feeding the insight engine.
select
    p.person_id,
    p.gender_concept_id,
    p.year_of_birth,
    count(distinct c.condition_concept_id) as distinct_conditions
from {{ ref('person_deid') }} p
left join {{ ref('condition_occurrence_deid') }} c on c.person_id = p.person_id
group by 1, 2, 3
