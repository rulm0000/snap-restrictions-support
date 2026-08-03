# SNAP_support

Psychological factors associated with support for SNAP soft-drink/candy restrictions (Wave 2 Numerator survey).

Pre-registration: AsPredicted (v10) — *Psychological Factors Associated with Support for SNAP Restrictions*.

## Run order (Stata)

1. Edit local paths at the top of `01_prepare_data.do` / `02_main_analysis.do` if needed.
2. `do 01_prepare_data.do` — builds `output/snap_w2_analysis.dta` (not in git).
3. `do 02_main_analysis.do` — model, Wald tests, simple effects, figures in `output/figures/`.

## Data (not in this repo)

- Wave 2: `University of Chicago Booth_SNAP Benefits Survey Tracker (W2)_RAW DATA_07.29.26_V01.xlsx`
- Wave 1 (for Q14 only): `Numerator/Numerator_SNAP Restrictions_BL data_raw.csv`
- State crosswalk: `state_restriction_status.csv` (in repo)

## Analysis notes / deviations from prereg

- **Q14 (soda overconsumption):** empty in Wave 2; merged from Wave 1 (Dec 2025) by `user_id`.
- **Weights:** none in the delivered files; primary models are **unweighted**. Code can accept a weight variable later.
- **Predictors:** continuous (overconsume 1–4; risk, embarrass, stigma 1–5). Stigma = mean of Q7 (disrespectful) + Q8 (agency).
- **SEs:** clustered by state (`vce(cluster state)`).
- **Exclusions:** complete case; Q4 "Don't Know" excluded; Q5 "did not pay with benefits" → missing embarrassment.
- **Restriction status:** hand-coded 4-level covariate from Allcott et al. PAP Table 1 (March 2026) + June 22, 2026 *Aragon v. Rollins* vacatur. See notes in `state_restriction_status.csv`.

## Sample (from last prep run)

- Wave 2 N = 9,014
- After excluding Don't Know SNAP: 8,765
- Complete-case analysis N = 8,715
