"""Load pipeline.yml and .env into one settings object. One place, so every stage agrees."""
import os
from pathlib import Path
import yaml

ROOT = Path(__file__).resolve().parents[2]


def _load_env(env_path: Path) -> None:
    """Minimal .env loader (avoids an extra dependency for a demo)."""
    if not env_path.exists():
        return
    for line in env_path.read_text().splitlines():
        line = line.strip()
        if line and not line.startswith("#") and "=" in line:
            key, _, val = line.partition("=")
            os.environ.setdefault(key.strip(), val.split("#")[0].strip())


class Settings:
    def __init__(self) -> None:
        _load_env(ROOT / ".env")
        self.cfg = yaml.safe_load((ROOT / "config" / "pipeline.yml").read_text())
        self.root = ROOT

    # --- pipeline.yml passthrough ---
    @property
    def omop_version(self) -> str:
        return self.cfg["omop_version"]

    @property
    def sources(self) -> list:
        return self.cfg["sources"]

    def path(self, key: str) -> Path:
        return (self.root / self.cfg["paths"][key]).resolve()

    # --- Snowflake connection params from env ---
    @property
    def snowflake(self) -> dict:
        return {
            "account": os.environ["SNOWFLAKE_ACCOUNT"],
            "user": os.environ["SNOWFLAKE_USER"],
            "role": os.environ.get("SNOWFLAKE_ROLE", "SYSADMIN"),
            "warehouse": os.environ.get("SNOWFLAKE_WAREHOUSE", "COMPUTE_WH"),
            "database": os.environ["SNOWFLAKE_DATABASE"],
            "private_key_path": os.environ["SNOWFLAKE_PRIVATE_KEY_PATH"],
            "private_key_passphrase": os.environ.get("SNOWFLAKE_PRIVATE_KEY_PASSPHRASE"),
        }

    def schema(self, name: str) -> str:
        return os.environ.get(f"{name}_SCHEMA", name)


settings = Settings()
