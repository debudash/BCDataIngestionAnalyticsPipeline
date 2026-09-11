"""Download and unpack a cBioPortal study tarball (METABRIC, TCGA-BRCA) to local staging.

cBioPortal ships each study as flat, tab-delimited files inside a .tar.gz. No API key.
"""
import tarfile
from pathlib import Path
import requests

from src.common.config import settings


def download_study(source: dict) -> Path:
    dest = settings.root / source["local_dir"]
    dest.mkdir(parents=True, exist_ok=True)
    tarball = dest / f"{source['study_id']}.tar.gz"

    if not tarball.exists():
        print(f"  downloading {source['url']}")
        with requests.get(source["url"], stream=True, timeout=120) as r:
            r.raise_for_status()
            with open(tarball, "wb") as f:
                for chunk in r.iter_content(chunk_size=1 << 20):
                    f.write(chunk)

    with tarfile.open(tarball) as tar:
        tar.extractall(dest, filter="data")   # flat files land under dest/<study_id>/
    print(f"  extracted {source['study_id']} -> {dest}")
    return dest


def run() -> None:
    for source in settings.sources:
        if source["kind"] == "real":
            print(f"[stage1] cBioPortal: {source['name']}")
            download_study(source)


if __name__ == "__main__":
    run()
