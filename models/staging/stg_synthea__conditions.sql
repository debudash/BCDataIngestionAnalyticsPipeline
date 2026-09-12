select
    "PATIENT"                as person_source_value,
    "CODE"                   as snomed_code,
    "DESCRIPTION"            as condition_source_value,
    try_to_date("START")     as condition_start_date
from {{ source('raw', 'synthea__conditions') }}
