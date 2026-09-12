-- Stage 4: Safe Harbor over PROCEDURE_OCCURRENCE. Date truncated to year; the free-text
-- description dropped because procedure_concept_id already carries it.
select
    procedure_occurrence_id,
    person_id,
    procedure_concept_id,
    year(procedure_date) as procedure_year
from {{ ref('procedure_occurrence') }}
