"""Snowflake connection (key-pair auth) plus two helpers: run_sql and load_dataframe.

Key-pair auth keeps secrets out of the code: we read a PKCS8 private key the user
generated and registered on their Snowflake user. We never see or store a password.
"""
from pathlib import Path
from cryptography.hazmat.backends import default_backend
from cryptography.hazmat.primitives import serialization
import snowflake.connector
from snowflake.connector.pandas_tools import write_pandas

from src.common.config import settings


def _private_key_bytes() -> bytes:
    sf = settings.snowflake
    passphrase = sf["private_key_passphrase"]
    key = serialization.load_pem_private_key(
        Path(sf["private_key_path"]).read_bytes(),
        password=passphrase.encode() if passphrase else None,
        backend=default_backend(),
    )
    return key.private_bytes(
        encoding=serialization.Encoding.DER,
        format=serialization.PrivateFormat.PKCS8,
        encryption_algorithm=serialization.NoEncryption(),
    )


def connect():
    sf = settings.snowflake
    return snowflake.connector.connect(
        account=sf["account"],
        user=sf["user"],
        role=sf["role"],
        warehouse=sf["warehouse"],
        database=sf["database"],
        private_key=_private_key_bytes(),
    )


def run_sql(sql: str, schema: str | None = None) -> list:
    """Run one or more ';'-separated statements. Returns rows of the last statement."""
    with connect() as conn:
        cur = conn.cursor()
        if schema:
            cur.execute(f"USE SCHEMA {schema}")
        rows = []
        for stmt in [s for s in sql.split(";") if s.strip()]:
            cur.execute(stmt)
            rows = cur.fetchall() if cur.description else []
        return rows


def load_dataframe(df, table: str, schema: str) -> int:
    """Bulk-load a DataFrame into schema.table, creating/replacing it. Returns row count."""
    with connect() as conn:
        conn.cursor().execute(f"CREATE SCHEMA IF NOT EXISTS {schema}")
        success, _, nrows, _ = write_pandas(
            conn, df, table.upper(), schema=schema, auto_create_table=True, overwrite=True
        )
        if not success:
            raise RuntimeError(f"Load failed for {schema}.{table}")
        return nrows
