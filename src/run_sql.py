"""
run_sql.py
----------
Phase 2 runner. Two jobs:
  1. Build the DuckDB database (data/loans.duckdb) by running sql/schema.sql.
  2. Run every query in sql/eda_queries.sql and save each result to outputs/eda/<name>.csv.

Queries in eda_queries.sql are separated by a marker line:
    -- name: q02_default_by_grade
Blocks that contain no SQL yet (just comments) are skipped, so you can
fill in queries one at a time and re-run.

Usage (from the repo root, venv active):
    python src/run_sql.py              # build DB if needed, run all queries
    python src/run_sql.py --rebuild    # force schema.sql to run again
    python src/run_sql.py q02          # run only queries whose name contains 'q02'
"""

import os
import re
import sys
from pathlib import Path

import duckdb

REPO_ROOT = Path(__file__).resolve().parent.parent
DB_PATH = REPO_ROOT / "data" / "loans.duckdb"
SCHEMA_SQL = REPO_ROOT / "sql" / "schema.sql"
EDA_SQL = REPO_ROOT / "sql" / "eda_queries.sql"
EDA_OUT = REPO_ROOT / "outputs" / "eda"


def build_database(con):
    """Run schema.sql (creates loans_raw view, loans table, loans_scoped view)."""
    print("Building database from sql/schema.sql (about 30-60 seconds)...")
    con.execute(SCHEMA_SQL.read_text())
    n_loans = con.execute("SELECT COUNT(*) FROM loans").fetchone()[0]
    n_scoped = con.execute("SELECT COUNT(*) FROM loans_scoped").fetchone()[0]
    print(f"  loans table: {n_loans:,} rows | loans_scoped view: {n_scoped:,} rows")


def split_queries(sql_text):
    """Split the file on '-- name: xxx' lines -> list of (name, sql)."""
    parts = re.split(r"^--\s*name:\s*(\S+)\s*$", sql_text, flags=re.MULTILINE)
    # re.split with a capture group gives: [preamble, name1, body1, name2, body2, ...]
    return list(zip(parts[1::2], parts[2::2]))


def has_real_sql(body):
    """True if the block has at least one line that isn't a comment or blank."""
    return any(line.strip() and not line.strip().startswith("--") for line in body.splitlines())


def main():
    args = sys.argv[1:]
    rebuild = "--rebuild" in args
    name_filter = next((a for a in args if not a.startswith("--")), None)

    # The schema uses a relative path to the CSV, so run from the repo root.
    os.chdir(REPO_ROOT)

    con = duckdb.connect(str(DB_PATH))
    tables = {r[0] for r in con.execute("SELECT table_name FROM information_schema.tables").fetchall()}
    if rebuild or "loans" not in tables:
        build_database(con)

    EDA_OUT.mkdir(parents=True, exist_ok=True)
    for name, body in split_queries(EDA_SQL.read_text()):
        if name_filter and name_filter not in name:
            continue
        if not has_real_sql(body):
            print(f"\n[{name}] skipped (no SQL yet)")
            continue
        print(f"\n[{name}]")
        try:
            df = con.execute(body).df()
        except duckdb.Error as e:
            print(f"  ERROR: {e}")
            continue
        df.to_csv(EDA_OUT / f"{name}.csv", index=False)
        print(df.head(15).to_string(index=False))
        print(f"  -> saved outputs/eda/{name}.csv ({len(df)} rows)")

    con.close()


if __name__ == "__main__":
    main()
