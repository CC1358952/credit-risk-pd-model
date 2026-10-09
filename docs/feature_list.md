# Feature List

Every column in `data/processed/model_table.parquet` (545,779 loans x 75 columns), where it came from, how it was treated, and why it is in the model.

**Authorship:** Raw-column reasoning is drafted by Claude from `docs/feature_review.csv` (which Caleb reviewed). Reasoning for engineered features and flags is written by Caleb. Cleaning code is Caleb's (`notebooks/02_cleaning.ipynb`).

## Not model inputs

| Column | Purpose |
|---|---|
| `id` | Loan identifier; joins results back to source (Phase 6) |
| `default_flag` | TARGET: 1 = Charged Off/Default, 0 = Fully Paid |
| `issue_year` | Train/test split: train 2013-14, test 2015 |
| `issue_date` | Used to compute credit_history_months; not a model input |
| `funded_amnt` | Exposure at default (EAD) for Phase 5 expected loss. Equals loan_amnt for all but 2 loans, so it is excluded as a feature to avoid duplication |

## Engineered features and flags (Caleb)

| Feature | Built from | Why it helps predict default |
|---|---|---|
| `credit_history_months` | issue_date - earliest_cr_line, in months | The months of credit history allows the model to actually use a numerical factor rather than just two dates|
| `log_annual_inc` | log(annual_inc) | Scales back the impact annual income has on the model as changes in annual income matter most at the lower end|
| `loan_to_income` | loan_amnt / annual_inc | Accounts for differences in scales of annual income for different loans as the same loan amount for someone with less annual income is more risky |
| `fico` | average of fico_range_low and fico_range_high (originals dropped) |The range between the two is consistantly around 4 points so just use the midpoint between the spread|
| `emp_length_missing` | 1 if emp_length was blank, before median fill | the emp length missing is a signal for credit risk |
| `ever_*` (6 flags) | 1 if the matching `mths_since_*` column was not blank |Adds multiple flags for different factors so that a "null" value factors into the model if there is a business reason for nulls to acceft credit risk |

## Raw application-time features

Missing-value treatment: **never-happened** = blank means the event never occurred; flag created, then filled with column max. **train median** = filled with the 2013-14 median only (no test-set leakage). **none** = no blanks.

| Feature | Type | Missing treatment | Reasoning (from leakage review) |
|---|---|---|---|
| `loan_amnt` | DOUBLE | none | Requested amount; use for loan-to-income |
| `emp_length` | BIGINT | train median; text parsed to years ('< 1 year' = 0, '10+' = 10) | Years employed. Correlates with age (protected under ECOA), so document it; generally acceptable as a stability measure |
| `home_ownership` | VARCHAR | none; 2 'ANY' -> RENT | Housing status from the application; merge the 2 'ANY' rows |
| `annual_inc` | DOUBLE | none | Self-reported income; use log and loan-to-income |
| `verification_status` | VARCHAR | none | Whether income was verified; set before funding |
| `purpose` | VARCHAR | none; wedding/renewable_energy/educational -> other | Stated loan purpose; group rare categories |
| `dti` | DOUBLE | none | Debt-to-income at application |
| `delinq_2yrs` | DOUBLE | none | Credit-bureau negative events as of application |
| `inq_last_6mths` | DOUBLE | none | Credit-bureau negative events as of application |
| `mths_since_last_delinq` | DOUBLE | never-happened | Mostly empty because NULL means 'never happened'. Don't drop: turn into 'ever had X' flags |
| `mths_since_last_record` | DOUBLE | never-happened | Mostly empty because NULL means 'never happened'. Don't drop: turn into 'ever had X' flags |
| `open_acc` | DOUBLE | none | Credit-bureau balances, limits and utilization at application. Many overlap: expect to prune correlated ones in Phase 4 |
| `pub_rec` | DOUBLE | none | Credit-bureau negative events as of application |
| `revol_bal` | DOUBLE | none | Credit-bureau balances, limits and utilization at application. Many overlap: expect to prune correlated ones in Phase 4 |
| `revol_util` | DOUBLE | train median | Credit-bureau balances, limits and utilization at application. Many overlap: expect to prune correlated ones in Phase 4 |
| `total_acc` | DOUBLE | none | Credit-bureau balances, limits and utilization at application. Many overlap: expect to prune correlated ones in Phase 4 |
| `collections_12_mths_ex_med` | DOUBLE | none | Credit-bureau negative events as of application |
| `mths_since_last_major_derog` | DOUBLE | never-happened | Mostly empty because NULL means 'never happened'. Don't drop: turn into 'ever had X' flags |
| `acc_now_delinq` | DOUBLE | none | Credit-bureau negative events as of application |
| `tot_coll_amt` | DOUBLE | none | Credit-bureau negative events as of application |
| `tot_cur_bal` | DOUBLE | none | Credit-bureau balances, limits and utilization at application. Many overlap: expect to prune correlated ones in Phase 4 |
| `total_rev_hi_lim` | DOUBLE | none | Credit-bureau balances, limits and utilization at application. Many overlap: expect to prune correlated ones in Phase 4 |
| `acc_open_past_24mths` | DOUBLE | none | Recency of credit activity at application (recent account openings signal credit seeking) |
| `avg_cur_bal` | DOUBLE | train median | Credit-bureau balances, limits and utilization at application. Many overlap: expect to prune correlated ones in Phase 4 |
| `bc_open_to_buy` | DOUBLE | train median | Credit-bureau balances, limits and utilization at application. Many overlap: expect to prune correlated ones in Phase 4 |
| `bc_util` | DOUBLE | train median | Credit-bureau balances, limits and utilization at application. Many overlap: expect to prune correlated ones in Phase 4 |
| `chargeoff_within_12_mths` | DOUBLE | none | Credit-bureau negative events as of application |
| `delinq_amnt` | DOUBLE | none | Credit-bureau negative events as of application |
| `mo_sin_old_il_acct` | DOUBLE | train median | Recency of credit activity at application (recent account openings signal credit seeking) |
| `mo_sin_old_rev_tl_op` | DOUBLE | none | Recency of credit activity at application (recent account openings signal credit seeking) |
| `mo_sin_rcnt_rev_tl_op` | DOUBLE | none | Recency of credit activity at application (recent account openings signal credit seeking) |
| `mo_sin_rcnt_tl` | DOUBLE | none | Recency of credit activity at application (recent account openings signal credit seeking) |
| `mort_acc` | DOUBLE | none | Credit-bureau balances, limits and utilization at application. Many overlap: expect to prune correlated ones in Phase 4 |
| `mths_since_recent_bc` | DOUBLE | train median | Recency of credit activity at application (recent account openings signal credit seeking) |
| `mths_since_recent_bc_dlq` | DOUBLE | never-happened | Mostly empty because NULL means 'never happened'. Don't drop: turn into 'ever had X' flags |
| `mths_since_recent_inq` | DOUBLE | never-happened | Recency of credit activity at application (recent account openings signal credit seeking) |
| `mths_since_recent_revol_delinq` | DOUBLE | never-happened | Mostly empty because NULL means 'never happened'. Don't drop: turn into 'ever had X' flags |
| `num_accts_ever_120_pd` | DOUBLE | none | Account counts by type at application. Highly overlapping: prune in Phase 4 |
| `num_actv_bc_tl` | DOUBLE | none | Account counts by type at application. Highly overlapping: prune in Phase 4 |
| `num_actv_rev_tl` | DOUBLE | none | Account counts by type at application. Highly overlapping: prune in Phase 4 |
| `num_bc_sats` | DOUBLE | none | Account counts by type at application. Highly overlapping: prune in Phase 4 |
| `num_bc_tl` | DOUBLE | none | Account counts by type at application. Highly overlapping: prune in Phase 4 |
| `num_il_tl` | DOUBLE | none | Account counts by type at application. Highly overlapping: prune in Phase 4 |
| `num_op_rev_tl` | DOUBLE | none | Account counts by type at application. Highly overlapping: prune in Phase 4 |
| `num_rev_accts` | DOUBLE | train median | Account counts by type at application. Highly overlapping: prune in Phase 4 |
| `num_rev_tl_bal_gt_0` | DOUBLE | none | Account counts by type at application. Highly overlapping: prune in Phase 4 |
| `num_sats` | DOUBLE | none | Account counts by type at application. Highly overlapping: prune in Phase 4 |
| `num_tl_120dpd_2m` | DOUBLE | train median | Account counts by type at application. Highly overlapping: prune in Phase 4 |
| `num_tl_30dpd` | DOUBLE | none | Account counts by type at application. Highly overlapping: prune in Phase 4 |
| `num_tl_90g_dpd_24m` | DOUBLE | none | Account counts by type at application. Highly overlapping: prune in Phase 4 |
| `num_tl_op_past_12m` | DOUBLE | none | Recency of credit activity at application (recent account openings signal credit seeking) |
| `pct_tl_nvr_dlq` | DOUBLE | train median | Credit-bureau balances, limits and utilization at application. Many overlap: expect to prune correlated ones in Phase 4 |
| `percent_bc_gt_75` | DOUBLE | train median | Credit-bureau balances, limits and utilization at application. Many overlap: expect to prune correlated ones in Phase 4 |
| `pub_rec_bankruptcies` | DOUBLE | none | Credit-bureau negative events as of application |
| `tax_liens` | DOUBLE | none | Credit-bureau negative events as of application |
| `tot_hi_cred_lim` | DOUBLE | none | Credit-bureau balances, limits and utilization at application. Many overlap: expect to prune correlated ones in Phase 4 |
| `total_bal_ex_mort` | DOUBLE | none | Credit-bureau balances, limits and utilization at application. Many overlap: expect to prune correlated ones in Phase 4 |
| `total_bc_limit` | DOUBLE | none | Credit-bureau balances, limits and utilization at application. Many overlap: expect to prune correlated ones in Phase 4 |
| `total_il_high_credit_limit` | DOUBLE | none | Credit-bureau balances, limits and utilization at application. Many overlap: expect to prune correlated ones in Phase 4 |

## Open questions for Phase 4

- `annual_inc` is still present alongside `log_annual_inc`; keep only one in the model (likely the log).
- Many bureau count/balance features overlap heavily; check correlations and prune.
- Income outliers: implied incomes range from about $3K to $8.9M; consider capping.
- `emp_length` and `credit_history_months` correlate with age (ECOA-protected): documented, standard practice, revisit in the fair-lending section of the memo.
