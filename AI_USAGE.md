# AI Usage Log

Every meaningful contribution from an AI tool is logged here, along with what I (Caleb) verified or changed.
Tools: Claude (Cowork) for pair programming, review and drafting; a local LLM via Ollama for reason codes (Phase 6).

| Date | Phase | What AI did | What I verified or changed |
|---|---|---|---|
| 2026-10-06 | 1 - Setup | Scaffolded repo folders, `.gitignore`, `requirements.txt`, and drafted `src/download_data.py` (Kaggle download + row-count check) | I read through the loading scripts to confirm it's compatability and verified the output of the 2.26M loans being imported, and integrated the API token connection for Kaggle |
| 2026-10-07 | 2 - SQL | Wrote `sql/schema.sql` (raw view -> typed table -> scoped view, target definition), `src/run_sql.py` runner, and the q00 worked example; q01-q09 left as prompts for me to write | I built each of the queries by hand and verified them in DuckDB as well as drew conclusions from the findings |
| 2026-10-07 | 3 - Features | Leakage/proxy review (brief prompt B): classified all 151 raw columns into `docs/feature_review.csv` with fill rates for the scoped loans, a keep/drop recommendation, reasoning, and a confidence level. Checked several claims against the data (constant columns, FICO spread, joint apps) |I verified each of the medium confidence features and concu=luded to include them each |
| 2026-10-08 | 3 - Features | Wrote the notebook setup cell (repo-root chdir), gave step-by-step prompts for the cleaning notebook, reviewed each of my cells (caught index-vs-column, index-alignment wipes, imputation leakage, timedelta type, notebook hidden state), and drafted `docs/feature_list.md` from my final table + the review CSV | I wrote both the cleaning code and reasoning for the changes made and its impact on the quality of the data to be entered into the model |
