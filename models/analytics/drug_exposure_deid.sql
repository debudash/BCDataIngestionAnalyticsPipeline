-- Stage 4: Safe Harbor over DRUG_EXPOSURE. Both dates truncate to year, so treatment can be
-- counted per year but not sequenced within a patient. The free-text drug name is dropped;
-- drug_concept_id carries the ingredient.
select
    drug_exposure_id,
    person_id,
    drug_concept_id,
    year(drug_exposure_start_date) as drug_exposure_start_year,
    year(drug_exposure_end_date)   as drug_exposure_end_year,
    quantity
from {{ ref('drug_exposure') }}
