"""Load every staged flat file into the Snowflake RAW schema, one table per file.

Raw = unrefined: we preserve source columns as-is (all VARCHAR via pandas) so Stage 2
transforms from a faithful copy. Table naming: <source>__<filename>.
"""
from pathlib import Path
import pandas as pd

from src.common.config import settings
from src.common.snowflake_io import load_dataframe


def _read_flat(path: Path) -> pd.DataFrame:
    # cBioPortal files are tab-delimited with '#'-comment header lines; Synthea is CSV.
    sep = "\t" if path.suffix == ".txt" else ","
    return pd.read_csv(path, sep=sep, comment="#", dtype=str, keep_default_na=False)


def _stage_files(source: dict) -> list[Path]:
    base = settings.root / source["local_dir"]
    if source["kind"] == "synthetic":
        return sorted((base / "csv").glob("*.csv"))
    return sorted(base.rglob("data_clinical_*.txt")) + sorted(base.rglob("data_*.txt"))


def run() -> None:
    raw = settings.schema("RAW")
    for source in settings.sources:
        for path in _stage_files(source):
            table = f"{source['name']}__{path.stem}"
            df = _read_flat(path)
            n = load_dataframe(df, table, raw)
            print(f"[stage1] loaded {raw}.{table}: {n} rows")


if __name__ == "__main__":
    run()
