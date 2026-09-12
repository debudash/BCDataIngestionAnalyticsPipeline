select
    "Id"                     as visit_source_value,
    "PATIENT"                as person_source_value,
    "ENCOUNTERCLASS"         as encounter_class,
    try_to_date("START")     as visit_start_date,
    try_to_date("STOP")      as visit_end_date
from {{ source('raw', 'synthea__encounters') }}
