-- Numeric observations only (labs/vitals) -> OMOP MEASUREMENT.
select
    "PATIENT"                as person_source_value,
    "CODE"                   as loinc_code,
    "DESCRIPTION"            as measurement_source_value,
    try_to_double("VALUE")   as value_as_number,
    "UNITS"                  as unit_source_value,
    try_to_date("DATE")      as measurement_date
from {{ source('raw', 'synthea__observations') }}
where "TYPE" = 'numeric'
