-- OHDSI invariant: a clinical event must fall inside its person's observation period.
-- Tools that bound queries by period silently drop anything outside it, so a violation here
-- means data that exists in the schema but is invisible to ATLAS and Achilles.
-- Only persons who HAVE a period are checked; the dateless real sources are out of scope.
with dated_events as (
    select person_id, condition_start_date as event_date, 'condition' as src
    from {{ ref('condition_occurrence') }} where condition_start_date is not null
    union all
    select person_id, visit_start_date, 'visit'
    from {{ ref('visit_occurrence') }} where visit_start_date is not null
    union all
    select person_id, drug_exposure_start_date, 'drug'
    from {{ ref('drug_exposure') }} where drug_exposure_start_date is not null
    union all
    select person_id, procedure_date, 'procedure'
    from {{ ref('procedure_occurrence') }} where procedure_date is not null
)
select e.person_id, e.src, e.event_date,
       op.observation_period_start_date, op.observation_period_end_date
from dated_events e
join {{ ref('observation_period') }} op on op.person_id = e.person_id
where e.event_date < op.observation_period_start_date
   or e.event_date > op.observation_period_end_date
