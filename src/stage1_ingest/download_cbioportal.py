"""Download the cBioPortal study files we need (METABRIC, TCGA-BRCA) to local staging.

Source is the cBioPortal datahub repo on GitHub, which stores each study as a folder of
flat, tab-delimited files under public/<study_id>/. We fetch only the four files declared
in pipeline.yml (two clinical, two genomic) rather than a whole-study tarball, so we skip
the hundreds of MB of expression and methylation data the pipeline never reads.

If a mutations file is missing upstream (TCGA-BRCA's datahub LFS object is absent today),
we fall back to the public cBioPortal REST API and write the rows out under the same MAF
column names METABRIC's file uses, so both mutation tables share one shape.
"""
import csv
from pathlib import Path
import requests

from src.common.config import settings

# MAF columns, in METABRIC's order. The API fills the ones mapped in API_TO_MAF below;
# the rest stay empty, which is ordinary for a MAF assembled from a subset of fields.
MAF_COLUMNS = [
    "Hugo_Symbol", "Entrez_Gene_Id", "Center", "NCBI_Build", "Chromosome",
    "Start_Position", "End_Position", "Strand", "Consequence", "Variant_Classification",
    "Variant_Type", "Reference_Allele", "Tumor_Seq_Allele1", "Tumor_Seq_Allele2",
    "dbSNP_RS", "dbSNP_Val_Status", "Tumor_Sample_Barcode", "Matched_Norm_Sample_Barcode",
    "Match_Norm_Seq_Allele1", "Match_Norm_Seq_Allele2", "Tumor_Validation_Allele1",
    "Tumor_Validation_Allele2", "Match_Norm_Validation_Allele1",
    "Match_Norm_Validation_Allele2", "Verification_Status", "Validation_Status",
    "Mutation_Status", "Sequencing_Phase", "Sequence_Source", "Validation_Method",
    "Score", "BAM_File", "Sequencer", "t_ref_count", "t_alt_count", "n_ref_count",
    "n_alt_count", "HGVSc", "HGVSp", "HGVSp_Short", "Transcript_ID", "RefSeq",
    "Protein_position", "Codons", "Hotspot",
]

API_TO_MAF = {
    "entrezGeneId": "Entrez_Gene_Id", "center": "Center", "ncbiBuild": "NCBI_Build",
    "chr": "Chromosome", "startPosition": "Start_Position", "endPosition": "End_Position",
    "mutationType": "Variant_Classification", "variantType": "Variant_Type",
    "referenceAllele": "Reference_Allele", "variantAllele": "Tumor_Seq_Allele2",
    "sampleId": "Tumor_Sample_Barcode", "validationStatus": "Validation_Status",
    "mutationStatus": "Mutation_Status", "tumorRefCount": "t_ref_count",
    "tumorAltCount": "t_alt_count", "normalRefCount": "n_ref_count",
    "normalAltCount": "n_alt_count", "proteinChange": "HGVSp_Short",
    "refseqMrnaId": "RefSeq", "proteinPosStart": "Protein_position",
}

PAGE_SIZE = 10000


def study_files() -> list[str]:
    groups = settings.cfg["cbioportal_files"]
    return groups["clinical"] + groups["genomic"]


def download_file(source: dict, filename: str) -> Path | None:
    dest = settings.root / source["local_dir"] / source["study_id"]
    dest.mkdir(parents=True, exist_ok=True)
    path = dest / filename

    if path.exists() and path.stat().st_size > 0:
        print(f"  have {filename} ({path.stat().st_size / 1e6:.1f} MB)")
        return path

    url = f"{settings.cfg['cbioportal_base_url']}/{source['study_id']}/{filename}"
    with requests.get(url, stream=True, timeout=120) as r:
        if r.status_code != 200:
            print(f"  MISSING {filename} (HTTP {r.status_code}) â€” skipping")
            return None
        with open(path, "wb") as f:
            for chunk in r.iter_content(chunk_size=1 << 20):
                f.write(chunk)
    print(f"  downloaded {filename} ({path.stat().st_size / 1e6:.1f} MB)")
    return path


def _maf_row(mutation: dict) -> list[str]:
    row = dict.fromkeys(MAF_COLUMNS, "")
    row["Hugo_Symbol"] = mutation.get("gene", {}).get("hugoGeneSymbol", "")
    for api_field, maf_column in API_TO_MAF.items():
        value = mutation.get(api_field)
        if value is not None:
            row[maf_column] = str(value)
    return [row[c] for c in MAF_COLUMNS]


def fetch_mutations_from_api(source: dict) -> Path | None:
    """Page the REST API for a study's mutations and write them as a MAF-shaped TSV."""
    study = source["study_id"]
    url = (f"{settings.cfg['cbioportal_api_url']}/molecular-profiles"
           f"/{study}_mutations/mutations/fetch")
    body = {"sampleListId": f"{study}_sequenced"}
    path = settings.root / source["local_dir"] / study / "data_mutations.txt"

    print(f"  falling back to the REST API for {study} mutations")
    with open(path, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f, delimiter="\t", lineterminator="\n")
        writer.writerow(MAF_COLUMNS)
        written, page = 0, 0
        while True:
            params = {"projection": "DETAILED", "pageSize": PAGE_SIZE, "pageNumber": page}
            r = requests.post(url, json=body, params=params, timeout=300)
            r.raise_for_status()
            mutations = r.json()
            if not mutations:
                break
            writer.writerows(_maf_row(m) for m in mutations)
            written += len(mutations)
            page += 1
            print(f"    page {page}: {written:,} mutations so far")

    if written == 0:
        path.unlink()
        print("    API returned no mutations — skipping")
        return None
    print(f"  wrote data_mutations.txt ({written:,} rows, MAF columns)")
    return path


def run() -> None:
    for source in settings.sources:
        if source["kind"] != "real":
            continue
        print(f"[stage1] cBioPortal: {source['name']}")
        for filename in study_files():
            got = download_file(source, filename)
            if got is None and filename == "data_mutations.txt":
                fetch_mutations_from_api(source)


if __name__ == "__main__":
    run()
