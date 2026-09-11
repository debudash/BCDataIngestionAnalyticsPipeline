-- Genomic parallel layer: mutations kept raw (NOT modeled in OMOP).
select * from {{ source('raw', 'metabric__data_mutations') }}
