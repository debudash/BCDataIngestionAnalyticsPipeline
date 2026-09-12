-- Synthea procedures (procedures.csv). CODE is SNOMED, resolved through the vocabulary at run
-- time; the concept_map marks this RESOLVE_AT_ETL. START/STOP are ISO timestamps.
select
    "PATIENT"                as person_source_value,
    "CODE"                   as snomed_code,
    "DESCRIPTION"            as procedure_source_value,
    try_to_date("START")     as procedure_date,
    "REASONCODE"             as reason_snomed_code
from {{ source('raw', 'synthea__procedures') }}
