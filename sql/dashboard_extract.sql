-- =====================================================================
-- dashboard_extract.sql  |  Phase 7: one row per 2015 test loan for Power BI
--
-- AUTHORSHIP: the SELECT / FROM / WHERE below is Caleb's own query,
-- saved character-for-character as he wrote it. Header comments by Claude.
--
-- Sources:
--   loans_scoped                                       (DuckDB view, Phase 2)
--   read_parquet('data/processed/scored_test.parquet') (model scores, Phase 4)
--
-- Output columns:
--   id, issue_date, grade, sub_grade, purpose, fico, int_rate, funded_amnt,
--   total_rec_int, default_flag, pd_lr, pd_lgbm, actual_loss, pd_decile
--
-- Run from notebooks/06_dashboard_prep.ipynb (saves data/processed/dashboard_loans.csv)
-- =====================================================================

SELECT id, issue_date, grade, sub_grade, purpose, (fico_range_low + fico_range_high) / 2 AS fico, int_rate, loans_scoped.funded_amnt, total_rec_int, loans_scoped.default_flag, pd_lr, pd_lgbm, ((loans_scoped.funded_amnt - total_rec_prncp - recoveries + collection_recovery_fee) * loans_scoped.default_flag) AS actual_loss, NTILE(10) OVER (ORDER BY pd_lr) AS pd_decile
FROM loans_scoped
JOIN read_parquet('data/processed/scored_test.parquet') AS scored_test USING (id)
WHERE issue_year = 2015
