"""Orchestrate the pipeline: Python for Stage 1 (extract/load), dbt for Stages 2-4.

    python run_pipeline.py --stage all     # EL, then dbt deps + build (run + test)
    python run_pipeline.py --stage 1        # ingest only (Python)
    python run_pipeline.py --stage 2        # dbt seed + run (staging, omop, genomic)
    python run_pipeline.py --stage 3        # dbt test (data quality)
    python run_pipeline.py --stage 4        # dbt run (analytics / de-id)

Importing settings loads .env into the environment, so the dbt subprocess inherits the
Snowflake vars that profiles.yml reads via env_var(). We point dbt at the project's own
profiles.yml with DBT_PROFILES_DIR.
"""
import argparse
import os
import subprocess
import sys

from src.common.config import settings  # side effect: loads .env into os.environ
from src.stage1_ingest import (
    download_cbioportal, download_synthea, load_raw_to_snowflake, load_vocabulary,
)

os.environ.setdefault("DBT_PROFILES_DIR", str(settings.root))


def stage1():
    download_synthea.run()
    download_cbioportal.run()
    load_raw_to_snowflake.run()
    load_vocabulary.run()      # loads VOCAB.CONCEPT for dbt code-resolve joins (no-op if absent)


def dbt(*args: str):
    cmd = ["dbt", *args]
    print(f"$ {' '.join(cmd)}")
    subprocess.run(cmd, cwd=settings.root, check=True)


STAGES = {
    "1": stage1,
    "2": lambda: (dbt("seed"), dbt("run", "--select", "staging", "omop", "genomic")),
    "3": lambda: dbt("test"),
    "4": lambda: dbt("run", "--select", "analytics"),
}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--stage", default="all", choices=["all", "1", "2", "3", "4"])
    args = ap.parse_args()
    try:
        if args.stage == "all":
            stage1()
            dbt("deps")
            dbt("build")          # seed + run + test, in dependency order
        else:
            STAGES[args.stage]()
    except subprocess.CalledProcessError as exc:
        print(f"\ndbt failed (exit {exc.returncode}).", file=sys.stderr)
        sys.exit(1)
    except Exception as exc:
        print(f"\nPipeline stopped: {exc}", file=sys.stderr)
        sys.exit(1)
    print("\nDone.")


if __name__ == "__main__":
    main()
