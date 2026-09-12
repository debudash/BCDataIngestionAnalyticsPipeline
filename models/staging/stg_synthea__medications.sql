-- Synthea medication dispenses (medications.csv). CODE is an RxNorm code, which the
-- vocabulary resolves at run time; the concept_map marks this RESOLVE_AT_ETL.
-- START and STOP are ISO timestamps; try_to_date takes the date part.
select
    "PATIENT"                as person_source_value,
    "CODE"                   as rxnorm_code,
    "DESCRIPTION"            as drug_source_value,
    try_to_date("START")     as drug_exposure_start_date,
    try_to_date("STOP")      as drug_exposure_end_date,
    try_to_double("DISPENSES") as dispenses,
    "REASONCODE"             as reason_snomed_code
from {{ source('raw', 'synthea__medications') }}
