-- Plausibility (singular test): no one dies before they are born.
-- Returns offending rows; dbt fails the test if any are returned.
select d.person_id, d.death_date, p.birth_datetime
from {{ ref('death') }} d
join {{ ref('person') }} p on p.person_id = d.person_id
where d.death_date < p.birth_datetime
