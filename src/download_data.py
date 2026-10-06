"""
download_data.py
----------------
Step 1 of the project: get the raw Lending Club data onto disk and prove it loads.

What it does:
  1. Downloads ONLY the accepted-loans file from Kaggle (we skip the rejected-applications
     file because we can't observe defaults for loans that were never made).
  2. Counts rows and columns with DuckDB (fast, and doesn't load 2M rows into memory).
  3. Saves the counts to outputs/data_load_check.json so the number is recorded, not remembered.

Requires a Kaggle API token, either:
  - new style: KAGGLE_API_TOKEN environment variable (or the token saved in ~/.kaggle/access_token)
  - legacy:    C:\\Users\\<you>\\.kaggle\\kaggle.json
Run from the repo root:  python src/download_data.py
"""

import json
import zipfile
from datetime import date
from pathlib import Path

import duckdb

# --- Settings -------------------------------------------------------------
DATASET = "wordsforthewise/lending-club"           # Kaggle dataset slug
FILE_NAME = "accepted_2007_to_2018Q4.csv.gz"         # the one file we need
REPO_ROOT = Path(__file__).resolve().parent.parent   # src/ -> repo root
RAW_DIR = REPO_ROOT / "data" / "raw"
OUTPUT_DIR = REPO_ROOT / "outputs"
RAW_FILE = RAW_DIR / FILE_NAME


def download():
    """Download the accepted-loans file from Kaggle, unless we already have it."""
    if RAW_FILE.exists():
        print(f"Already downloaded: {RAW_FILE.name} -- skipping download.")
        return

    # Imported here so the row-count step still works without the kaggle package
    from kaggle.api.kaggle_api_extended import KaggleApi

    api = KaggleApi()
    api.authenticate()  # finds your token (env var or ~/.kaggle); fails loudly if missing
    print(f"Downloading {FILE_NAME} from {DATASET} (~375 MB, a few minutes)...")
    api.dataset_download_file(DATASET, FILE_NAME, path=str(RAW_DIR))

    # Kaggle sometimes wraps single-file downloads in a .zip -- unwrap if so
    zipped = RAW_DIR / (FILE_NAME + ".zip")
    if zipped.exists():
        with zipfile.ZipFile(zipped) as z:
            z.extractall(RAW_DIR)
        zipped.unlink()

    if not RAW_FILE.exists():
        raise FileNotFoundError(
            f"Expected {RAW_FILE} after download. Check data/raw/ -- the file name on Kaggle may differ."
        )


def count_rows():
    """Count rows/columns with DuckDB and save the result."""
    con = duckdb.connect()  # in-memory database; nothing saved yet (Phase 2 builds the real one)

    # all_varchar=true: read every column as text. Lending Club has messy types and
    # two junk summary lines at the end; we only want counts right now, so text is safest.
    source = f"read_csv('{RAW_FILE.as_posix()}', all_varchar=true, ignore_errors=true)"

    total_rows = con.execute(f"SELECT COUNT(*) FROM {source}").fetchone()[0]
    # A real loan always has a loan amount; the junk footer lines don't.
    real_loans = con.execute(f"SELECT COUNT(*) FROM {source} WHERE loan_amnt IS NOT NULL").fetchone()[0]
    n_cols = len(con.execute(f"SELECT * FROM {source} LIMIT 1").description)

    result = {
        "file": FILE_NAME,
        "checked_on": date.today().isoformat(),
        "rows_read": total_rows,
        "loan_rows": real_loans,
        "columns": n_cols,
    }
    OUTPUT_DIR.mkdir(exist_ok=True)
    (OUTPUT_DIR / "data_load_check.json").write_text(json.dumps(result, indent=2))

    print(json.dumps(result, indent=2))
    print("Saved to outputs/data_load_check.json")


if __name__ == "__main__":
    RAW_DIR.mkdir(parents=True, exist_ok=True)
    download()
    count_rows()
