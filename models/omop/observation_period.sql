-- OMOP OBSERVATION_PERIOD — the span during which a person was under observation.
--
-- This table is what OHDSI tooling keys on. ATLAS cohort definitions, Achilles and the Data
-- Quality Dashboard all bound their logic by observation period: an event outside a person's
-- period is invisible to them, and a person with no period at all is invisible entirely.
-- Without this table the OMOP schema is queryable by hand but not by the OHDSI stack.
--
-- One continuous period per person, spanning the earliest to the latest dated clinical event.
-- That is the standard derivation for EHR-shaped data (and what ETL-Synthea does), rather
-- than trying to reconstruct enrolment gaps that the source never recorded.
--
-- COVERAGE LIMIT, deliberate: only Synthea patients appear here. METABRIC and TCGA-BRCA carry
-- no calendar date of any kind — only intervals like age at diagnosis and survival months — so
-- a period for them could only be invented. The same reasoning declined a METABRIC death date
-- (concept_map decision 1). The consequence is real and worth stating plainly: OHDSI tools
-- pointed at this schema will see the 5,013 Synthea patients and not the 3,593 others.
with events as (
    select person_id, visit_start_date as event_date from {{ ref('visit_occurrence') }}
    union all
    select person_id, visit_end_date from {{ ref('visit_occurrence') }}
    union all
    select person_id, condition_start_date from {{ ref('condition_occurrence') }}
    union all
    select person_id, measurement_date from {{ ref('measurement') }}
    union all
    select person_id, drug_exposure_start_date from {{ ref('drug_exposure') }}
    union all
    select person_id, drug_exposure_end_date from {{ ref('drug_exposure') }}
    union all
    select person_id, procedure_date from {{ ref('procedure_occurrence') }}
),
spans as (
    select person_id,
           min(event_date) as observation_period_start_date,
           max(event_date) as observation_period_end_date
    from events
    where event_date is not null
    group by person_id
)
select
    row_number() over (order by person_id) as observation_period_id,
    person_id,
    observation_period_start_date,
    observation_period_end_date,
    -- 32817 'EHR'. Synthea simulates an EHR, so the period is derived from recorded
    -- encounters rather than from an insurance enrolment file.
    32817 as period_type_concept_id
from spans
