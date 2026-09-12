-- Clean, typed view of Synthea patients. RAW is all-VARCHAR; we cast and rename here.
select
    "Id"                          as person_source_value,
    "GENDER"                      as gender_source_value,  -- Synthea uses 'M'/'F' (matches seed)
    lower("RACE")                 as race_source_value,
    lower("ETHNICITY")            as ethnicity_source_value,
    try_to_date("BIRTHDATE")      as birth_date,
    try_to_date("DEATHDATE")      as death_date
from {{ source('raw', 'synthea__patients') }}
