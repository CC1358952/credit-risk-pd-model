-- =====================================================================
-- schema.sql  |  Phase 2: build the DuckDB database in three layers
--
--   1. loans_raw     (VIEW)  the CSV exactly as published, every column as text
--   2. loans         (TABLE) the columns we need, cleaned and properly typed
--   3. loans_scoped  (VIEW)  the modeling population: 36-month loans issued
--                            2013-2015 that have a final outcome
--
-- Why layers? Same idea as Power Query staging queries: never edit the
-- source, clean in one place, and let everything downstream read the
-- clean version. If a cleaning rule is wrong, you fix it once here.
--
-- Run from the repo root (src/run_sql.py does this for you).
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. RAW LAYER
-- A VIEW stores only the query, not the data. Each time we select from it,
-- DuckDB re-reads the .csv.gz (~8 seconds). That keeps the database small
-- and keeps all 151 original columns available for the Phase 3 leakage review.
-- all_varchar = true: read everything as text so messy values can't break the load.
-- The WHERE drops the 33 footer/summary lines found in Phase 1.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW loans_raw AS
SELECT *
FROM read_csv('data/raw/accepted_2007_to_2018Q4.csv.gz',
              all_varchar = true, ignore_errors = true)
WHERE loan_amnt IS NOT NULL;


-- ---------------------------------------------------------------------
-- 2. CLEAN, TYPED LAYER
-- TRY_CAST returns NULL instead of crashing when a value can't convert,
-- so one bad cell doesn't kill a 2.26M-row load. (Compare: CAST would error.)
--
-- Columns kept fall into three groups:
--   A. Application-time fields  -> candidate model features (reviewed in Phase 3)
--   B. Outcome fields           -> used to build the target
--   C. Post-origination fields  -> LEAKAGE for modeling; kept ONLY for the
--                                  Phase 5 loss-given-default (LGD) estimate
-- ---------------------------------------------------------------------
CREATE OR REPLACE TABLE loans AS
SELECT
    TRY_CAST(id AS BIGINT)                                    AS id,

    -- A. Known at application time --------------------------------------
    TRY_CAST(loan_amnt   AS DOUBLE)                           AS loan_amnt,
    TRY_CAST(funded_amnt AS DOUBLE)                           AS funded_amnt,
    TRY_CAST(TRIM(REPLACE(term, 'months', '')) AS INTEGER)    AS term_months,   -- ' 36 months' -> 36
    TRY_CAST(REPLACE(int_rate,   '%', '') AS DOUBLE)          AS int_rate,      -- percent, e.g. 13.99
    TRY_CAST(installment AS DOUBLE)                           AS installment,
    grade,
    sub_grade,
    emp_length,                                               -- text like '10+ years'; parsed in Phase 3
    home_ownership,
    TRY_CAST(annual_inc AS DOUBLE)                            AS annual_inc,
    verification_status,
    purpose,
    addr_state,                                               -- possible fair-lending proxy; EDA only for now
    TRY_CAST(dti AS DOUBLE)                                   AS dti,
    TRY_CAST(fico_range_low  AS DOUBLE)                       AS fico_range_low,
    TRY_CAST(fico_range_high AS DOUBLE)                       AS fico_range_high,
    TRY_CAST(delinq_2yrs     AS DOUBLE)                       AS delinq_2yrs,
    TRY_CAST(inq_last_6mths  AS DOUBLE)                       AS inq_last_6mths,
    TRY_CAST(open_acc        AS DOUBLE)                       AS open_acc,
    TRY_CAST(pub_rec         AS DOUBLE)                       AS pub_rec,
    TRY_CAST(revol_bal       AS DOUBLE)                       AS revol_bal,
    TRY_CAST(REPLACE(revol_util, '%', '') AS DOUBLE)          AS revol_util,
    TRY_CAST(total_acc       AS DOUBLE)                       AS total_acc,
    TRY_CAST(mort_acc        AS DOUBLE)                       AS mort_acc,
    TRY_CAST(pub_rec_bankruptcies AS DOUBLE)                  AS pub_rec_bankruptcies,
    application_type,
    -- 'Aug-2003' -> 2003-08-01. strptime needs a day, so we glue on '01-'.
    TRY_CAST(TRY_STRPTIME('01-' || earliest_cr_line, '%d-%b-%Y') AS DATE) AS earliest_cr_line,

    -- B. Outcome -----------------------------------------------------------
    TRY_CAST(TRY_STRPTIME('01-' || issue_d, '%d-%b-%Y') AS DATE)          AS issue_date,
    YEAR(TRY_STRPTIME('01-' || issue_d, '%d-%b-%Y'))                      AS issue_year,
    loan_status,
    -- Target: 1 = bad (Charged Off / Default), 0 = good (Fully Paid),
    -- NULL = no final outcome yet (Current, Late, In Grace Period, ...)
    CASE
        WHEN loan_status IN ('Charged Off', 'Default') THEN 1
        WHEN loan_status = 'Fully Paid'                THEN 0
        ELSE NULL
    END                                                       AS default_flag,

    -- C. Post-origination (LEAKAGE - never use as model features) -----------
    TRY_CAST(total_pymnt             AS DOUBLE)               AS total_pymnt,
    TRY_CAST(total_rec_prncp         AS DOUBLE)               AS total_rec_prncp,
    TRY_CAST(total_rec_int           AS DOUBLE)               AS total_rec_int,
    TRY_CAST(recoveries              AS DOUBLE)               AS recoveries,
    TRY_CAST(collection_recovery_fee AS DOUBLE)               AS collection_recovery_fee
FROM loans_raw;


-- ---------------------------------------------------------------------
-- 3. MODELING POPULATION
-- 36-month loans issued 2013-2015 with a final outcome (default_flag not NULL).
-- Phases 3-5 all start from this view, so the scope is defined exactly once.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW loans_scoped AS
SELECT *
FROM loans
WHERE term_months = 36
  AND issue_year BETWEEN 2013 AND 2015
  AND default_flag IS NOT NULL;
