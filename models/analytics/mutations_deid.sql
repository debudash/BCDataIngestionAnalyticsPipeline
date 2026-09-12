-- Stage 4: de-identified genomic layer, both studies, keyed on person_id.
--
-- The sample and matched-normal barcodes are dropped: they are unique identifying numbers
-- under Safe Harbor, and they are also the join key back to the source studies. Everything
-- kept here is a variant call.
--
-- CAVEAT, and it is a real one. Removing the barcodes removes the DIRECT identifiers, but a
-- genome-wide variant profile is itself potentially re-identifying: enough variants uniquely
-- distinguish an individual and can be matched against other genomic datasets. Safe Harbor's
-- list does not name sequence data, and whether it falls under "any other unique identifying
-- characteristic" is contested rather than settled. Treat this model as de-identified
-- clinical metadata attached to genomic calls, not as a safe public release.
with mutations as (
    select 'metabric' as source, "Tumor_Sample_Barcode" as sample_id, "Hugo_Symbol" as hugo_symbol,
           "Entrez_Gene_Id" as entrez_gene_id, "Chromosome" as chromosome,
           "Start_Position" as start_position, "Variant_Classification" as variant_classification,
           "Variant_Type" as variant_type, "HGVSp_Short" as protein_change
    from {{ ref('metabric_mutations') }}
    union all
    select 'tcga_brca', "Tumor_Sample_Barcode", "Hugo_Symbol",
           "Entrez_Gene_Id", "Chromosome",
           "Start_Position", "Variant_Classification",
           "Variant_Type", "HGVSp_Short"
    from {{ ref('tcga_brca_mutations') }}
)
select
    sp.person_id,
    m.source,
    m.hugo_symbol,
    m.entrez_gene_id,
    m.chromosome,
    m.start_position,
    m.variant_classification,
    m.variant_type,
    m.protein_change
from mutations m
join {{ ref('sample_person') }} sp on sp.sample_id = m.sample_id
where sp.person_id is not null
