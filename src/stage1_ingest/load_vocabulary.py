"""Load the Athena OMOP CONCEPT table into Snowflake VOCAB schema (dbt's omop_vocab source).

Download vocabularies from https://athena.ohdsi.org (SNOMED, LOINC, RxNorm at minimum),
unzip, and place CONCEPT.csv in staging/vocabulary/. This is large (millions of rows);
for production use Snowflake COPY from a stage instead of pandas.
"""
import pandas as pd

from src.common.config import settings
from src.common.snowflake_io import load_dataframe

COLS = ["concept_id", "concept_name", "domain_id", "vocabulary_id",
        "concept_class_id", "standard_concept", "concept_code"]


def run() -> None:
    path = settings.path("vocabulary") / "CONCEPT.csv"
    if not path.exists():
        print(f"[stage1] no vocabulary at {path} — code-resolve joins will map to 0. "
              f"Download from https://athena.ohdsi.org")
        return
    df = pd.read_csv(path, sep="\t", dtype=str, keep_default_na=False, usecols=COLS)
    n = load_dataframe(df, "CONCEPT", "VOCAB")
    print(f"[stage1] loaded VOCAB.CONCEPT: {n} rows")


if __name__ == "__main__":
    run()
