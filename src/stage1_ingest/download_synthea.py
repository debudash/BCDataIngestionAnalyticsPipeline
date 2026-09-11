"""Obtain Synthea breast-cancer synthetic patients as CSV (the input ETL-Synthea expects).

Two paths, in order of preference:
  1. If CSVs already exist in staging/synthea/, use them (fastest for a demo).
  2. Otherwise, print the one command to generate them with the Synthea jar.
We do NOT bundle the ~100MB jar; generation is a documented, deliberate step.
"""
from pathlib import Path
from src.common.config import settings

SYNTHEA_CMD = (
    "java -jar synthea-with-dependencies.jar -m breast_cancer "
    "-p 500 --exporter.csv.export true --exporter.baseDirectory ./staging/synthea"
)


def run() -> Path:
    src = next(s for s in settings.sources if s["name"] == "synthea")
    csv_dir = settings.root / src["local_dir"] / "csv"
    if csv_dir.exists() and any(csv_dir.glob("*.csv")):
        print(f"[stage1] Synthea CSVs found -> {csv_dir}")
        return csv_dir
    print("[stage1] Synthea CSVs not found. Generate them with:\n  " + SYNTHEA_CMD)
    print("  (or drop pre-generated patients.csv, conditions.csv, ... into that folder)")
    return csv_dir


if __name__ == "__main__":
    run()
