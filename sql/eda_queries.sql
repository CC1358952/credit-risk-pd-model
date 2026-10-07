-- =====================================================================
-- eda_queries.sql  |  Phase 2 exploratory queries
--
-- AUTHORSHIP: every SELECT in q01-q09 is Caleb's own query, saved character-for-
-- character as he wrote it. The q00 worked example and all comment lines
-- (prompts, hints, [Claude note]) were written by Claude unless marked [Caleb].
--
-- Tables available (built by schema.sql):
--   loans         every loan 2007-2018, typed columns + default_flag (1/0/NULL)
--   loans_scoped  36-month loans, issued 2013-2015, final outcome only  <- use this by default
--
-- Each query starts with a "-- name:" line. run_sql.py saves its result to
-- outputs/eda/<name>.csv. Empty blocks are skipped, so fill in one at a
-- time and run:   python src/run_sql.py q01
--
-- Useful trick: default_flag is 1 or 0, so AVG(default_flag) IS the default rate.
-- =====================================================================


-- name: q00_scope_check
-- WORKED EXAMPLE (written by Claude, use it as the pattern).
-- Question: how many loans survive each scope filter?
-- Why it matters: every later number is about THIS population, and an
-- interviewer may ask "how many loans did you model, and why that many?"
SELECT 'all loans'                       AS step, COUNT(*) AS n_loans FROM loans
UNION ALL
SELECT '36-month, issued 2013-2015',             COUNT(*) FROM loans
    WHERE term_months = 36 AND issue_year BETWEEN 2013 AND 2015
UNION ALL
SELECT '... and has a final outcome (scoped)',   COUNT(*) FROM loans_scoped;


-- name: q01_default_by_grade
-- Default rate by grade (A-G). Return: grade, n_loans, n_defaults, default_rate_pct.
-- Order A -> G. Hint: ROUND(100 * AVG(default_flag), 2)
SELECT grade, COUNT(*) AS n_loans, SUM(CASE WHEN default_flag = 1 THEN 1 ELSE 0 END) AS n_defaults, ROUND(100*AVG(default_flag),2) AS default_rate_pct FROM loans_scoped GROUP BY grade ORDER BY grade;



-- name: q02_default_by_term
-- Default rate for 36- vs 60-month loans, issued 2013-2015, final outcome only.
-- Careful: loans_scoped only has 36-month loans. Which table do you need?
-- [Claude note] CAVEAT: ~24% of 2013-2015 60-month loans had no final outcome by 2018.
-- The resolved ones skew toward early defaults, so the 60-month rate is biased UPWARD.
SELECT term_months, COUNT(*) AS n_loans, ROUND(100*AVG(default_flag),2) AS default_rate_pct FROM loans WHERE issue_year >= 2013 AND issue_year <= 2015 AND default_flag NOT NULL GROUP BY term_months ORDER BY term_months;



-- name: q03_default_by_purpose
-- Default rate by loan purpose, highest rate first. Include n_loans.
-- Think: why is the count column important when comparing small categories?
SELECT purpose, COUNT(*) AS n_loans, ROUND(100*AVG(default_flag),2) AS default_rate_pct FROM loans_scoped  GROUP BY purpose HAVING COUNT(*) >= 1000  ORDER BY default_rate_pct DESC;



-- name: q04_default_by_home_ownership
-- Default rate by home_ownership (RENT, MORTGAGE, OWN, ...).
SELECT home_ownership, COUNT(*) AS n_loans, ROUND(100*AVG(default_flag),2) AS default_rate_pct FROM loans_scoped  GROUP BY home_ownership HAVING COUNT(*) >= 1000  ORDER BY default_rate_pct DESC;



-- name: q05_default_by_issue_year
-- Default rate by issue_year (2013, 2014, 2015). Is risk stable over time?
-- (This matters for Phase 4: we train on 2013-14 and test on 2015.)
SELECT issue_year, COUNT(*) AS n_loans, ROUND(100*AVG(default_flag),2) AS default_rate_pct FROM loans_scoped WHERE issue_year BETWEEN 2013 AND 2015 GROUP BY issue_year ORDER BY issue_year;



-- name: q06_default_by_income_band
-- Default rate by annual income band. Build the bands with CASE WHEN, e.g.
-- '<40k', '40-60k', '60-80k', '80-100k', '100-150k', '150k+'.
-- Challenge: make the bands sort in income order, not alphabetically.
SELECT CASE
WHEN annual_inc < 40000 THEN '<40k'
WHEN annual_inc >= 40000 AND annual_inc < 60000 THEN '40-60k'
WHEN annual_inc >= 60000 AND annual_inc < 80000 THEN '60-80k'
WHEN annual_inc >= 80000 AND annual_inc < 100000 THEN '80-100k'
WHEN annual_inc >= 100000 AND annual_inc < 150000 THEN '100-150k'
ELSE '150k+' END AS income_band, COUNT(*) AS n_loans, ROUND(100*AVG(default_flag),2) AS default_rate_pct FROM loans_scoped GROUP BY income_band ORDER BY MIN(annual_inc) ASC;



-- name: q07_rate_vs_default_by_grade
-- For each grade: average interest rate, default rate, and the gap between them.
-- Question to answer in words: is Lending Club charging enough for the risk?
--[CALEB] This query allowed me to discover a misleading metric underlying the grade. Seeing as annual interest rates are not to be compared with lifetime default rates allowed me to catch the error as having most loans lose money would mean the firm would be out of business very quickly.--
SELECT grade, ROUND(AVG(int_rate),2) AS avg_int_rate, ROUND(100*AVG(default_flag),2) AS default_rate_pct, ROUND((AVG(int_rate) - ROUND(100*AVG(default_flag),2)),2) AS spread FROM loans_scoped GROUP BY Grade ORDER BY grade



-- name: q08_volume_by_vintage
-- Loan count and total funded amount (funded_amnt) by issue_year.
-- Use ALL loans 2007-2018 (table loans), not just the scoped ones. Why?
SELECT issue_year, COUNT(*) AS n_loans, SUM(funded_amnt) AS total_funded FROM loans GROUP BY issue_year ORDER BY issue_year;



-- name: q09_default_by_fico_band
-- Your choice of one more cut. Suggested: default rate by FICO band
-- (fico_range_low in buckets of 20 or 40 points).
SELECT FLOOR(fico_range_low / 20) * 20 AS fico_band, COUNT(*) AS n_loans, ROUND(100 * AVG(default_flag), 2) AS default_rate_pct FROM loans_scoped GROUP BY FLOOR(fico_range_low / 20) * 20 ORDER BY fico_band ASC;
