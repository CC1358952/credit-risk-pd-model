# Build Log: who did what

A lightweight record of my work vs. AI assistance on this project, kept as I go.
Use it for LinkedIn, interviews, and the AI Usage section of the model memo.
(Detailed AI prompts and verification notes live in `AI_USAGE.md`.)

**Rule I followed:** SQL queries in `sql/eda_queries.sql` are saved exactly as I typed them. AI reviewed them and explained errors, but did not rewrite them.

---

## Phase 1: Setup and data (Oct 6, 2026)
**I did**
- Set up the Python virtual environment, Kaggle API token, Git repo, and GitHub remote
- Ran the download and verified the raw load: 2,260,668 loans, 151 columns

**AI did**
- Scaffolded the repo structure, `.gitignore`, `requirements.txt`
- Drafted `src/download_data.py` (I reviewed it)

## Phase 2: SQL layer (Oct 7, 2026)
**I did**
- Wrote all 9 EDA queries (q01-q09) in DuckDB SQL: default rate by grade, term, purpose, home ownership, issue year, income band, FICO band; interest rate vs. default by grade; volume by vintage
- Debugged my own errors with AI review: aggregate vs. raw columns, rate math, parenthesis mismatch, round-then-multiply precision loss, COUNT(*) vs. NULL-filtered denominators, HAVING vs. WHERE clause order, overlapping BETWEEN boundaries in income bands, typos caught by running before submitting
- Identified a misleading metric in my own q07 (annual interest rate vs. lifetime default rate) and documented why

**AI did**
- Wrote `sql/schema.sql` (raw view, typed table, scoped view) and `src/run_sql.py` runner
- Wrote the q00 scope-check example and the prompts for q01-q09
- Reviewed each of my queries and explained mistakes without rewriting them
- Ran supplementary checks to explain results (unresolved 60-month loans, within-grade default drift by year, net principal loss by grade)

**Findings**
- Scoped population: 546,018 loans (36-month, 2013-2015, final outcome); only 147 dropped as unresolved
- Default rate rises monotonically by grade (A 5.29% to G 41.46%), by FICO (660s 18.2% to 820s 2.7%), and falls with income (<$40k 19.3% to $150k+ 9.7%)
- 60-month default rate (32.63%) is biased upward because ~24% of those loans were unresolved, which supports modeling 36-month loans only
- Default rates rose each year 2013-2015 (12.3% to 14.9%) even within the same grade while interest rates fell, so the 2015 out-of-time test set is riskier than training data
- Small business is the riskiest purpose (22.9%); mortgage holders default less than outright owners (11.4% vs. 15.0%)

## Phase 3: Cleaning and features (Oct 7-8, 2026)
**I did**
- Made the modeling decisions: dropped Lending Club's grade/sub_grade/int_rate/installment (independent model, use their grade as a benchmark); excluded the 239 joint-application loans
- Wrote all cleaning and feature code in `notebooks/02_cleaning.ipynb`: built the column list from my review file, loaded 545,779 loans from DuckDB, converted types (2 GB to 0.3 GB) with a before/after null check, created 6 "ever had" flags for never-happened blanks, filled truly-missing values with training-only (2013-14) medians, parsed employment length, grouped rare categories, engineered credit history length, log income, loan-to-income and average FICO
- Saved the clean modeling table (545,779 x 75, zero missing values) to Parquet
- Debugged: row index vs. column values, pandas index alignment wiping 2015 rows, imputation leakage, Timedelta vs. numeric, notebook hidden state (adopted Restart and Run All)

**AI did**
- Classified all 151 raw columns for leakage / fair-lending / sparsity in `docs/feature_review.csv` (I reviewed and made the DECIDE calls)
- Wrote the notebook setup cell, gave step prompts, reviewed each cell
- Drafted `docs/feature_list.md` (I wrote the engineered-feature reasoning)

**Findings**
- 38 columns are post-origination leakage (e.g. debt_settlement_flag: 9,197 scoped loans flagged)
- Every scoped borrower has 3+ years of credit history and FICO 660+: Lending Club's own underwriting limits what the model can learn
- Borrowers with a recent credit inquiry default 14.6% vs. 9.7% without

## Phase 4: Modeling (Oct 9-13, 2026)
**I did**
- Wrote all modeling code in `notebooks/03_model.ipynb`: one-hot encoding, time-based split (train 2013-14: 262,992 loans; test 2015: 282,787), scaling fit on training data only, logistic regression (scikit-learn) and coefficient/p-value analysis (statsmodels)
- Benchmarked against Lending Club's own sub-grade on the same test loans (merge by id, sub-grade to 1-35 rank)
- Computed AUC, Gini, KS and a 10-decile calibration table
- Diagnosed multicollinearity from counterintuitive coefficient signs; found 24 correlated pairs (|r| > 0.8, training data), then used VIF to catch three-way redundancy (e.g. total_acc, pub_rec, revolving balance/limit vs. utilization)
- Made every keep/drop decision with written business reasoning (explainability to a declined applicant); pruned 80 -> 57 features

**AI did**
- Gave step prompts, explained concepts (AUC, KS, calibration, multicollinearity, VIF, dummy-variable VIF quirk), reviewed each cell
- Ran independent checks to verify my numbers (benchmark AUC, correlation pairs, VIF, preview refits) and flagged remaining wrong-sign coefficients

**Findings**
- Baseline (80 features): test AUC 0.684, Gini 0.37, KS 0.267, train AUC 0.677 (no overfitting)
- Lending Club sub-grade benchmark: AUC 0.679, KS 0.262 (my independent model is comparable)
- Calibration: actual default rate rises in every decile (3.6% to 31.9%, ~9x lift); model under-predicts 2015 defaults by a consistent ~7-12% (13.6% vs 14.9%) due to underwriting drift -> recalibration candidate
- Pruned model (57 features): test AUC 0.679; no non-dummy VIF > 10; all significant signs sensible except two documented (bankruptcies, income verification)
- LightGBM challenger (all 80 features): test AUC 0.696, train AUC 0.754 (overfitting gap ~0.06), KS 0.284
- Chose the pruned 57-feature logistic regression for production: modest accuracy gap vs. LightGBM (+0.017 AUC), no overfitting, and coefficients provide ECOA/Reg B adverse-action reasons; LightGBM kept as challenger
- Final chosen model: test AUC 0.679, Gini 0.358, KS 0.259; on par with Lending Club's own sub-grade (AUC 0.679, KS 0.262)
- Saved outputs/metrics.json and scored 2015 test loans (data/processed/scored_test.parquet) for Phase 5

---

## LinkedIn-ready summary (update at the end)
_To fill in once the project is complete, using only real results._
