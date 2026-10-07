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

---

## LinkedIn-ready summary (update at the end)
_To fill in once the project is complete, using only real results._
