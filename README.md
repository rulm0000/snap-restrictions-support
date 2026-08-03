# SNAP_support

Psychological factors associated with support for SNAP restrictions (AsPredicted v10).

## Purpose

Determine whether psychological predictors (self-reported soda overconsumption, perceived health risk of soda, perceived stigma of current SNAP policies, and embarrassment when paying with SNAP benefits) predict support for removing soft drinks and candy from SNAP-eligible food purchases, and whether these associations are moderated by SNAP participation.

## Analyses

- 1_Data_Preparation.do — Import/merge, recode outcome and predictors; perceived stigma = average of the two SNAP-policy stigma items (prereg §5); complete-case analysis sample.
- 2_Main_Analysis.do — VIF; linear regression with continuous predictors, SNAP, predictor×SNAP interactions, covariates; state-clustered SEs; Wald tests; simple effects; export plot CSVs.
- 3_Figures.py — Four-panel figures from those CSVs (model-adjusted + descriptive).
- 4_Tables.do — Table 1 (descriptives by SNAP), Table 2 (main effects), Table 3 (simple slopes by SNAP).

## Run

From this folder:

`
do 0_Master.do
`

Requires Stata plus Python with pandas and matplotlib. Raw Wave 1/2 survey files live outside the repo (not committed).

## Repository layout

`	ext
SNAP_support/
|-- 0_Master.do
|-- setup.do
|-- 1_Data_Preparation.do
|-- 2_Main_Analysis.do
|-- 3_Figures.py
|-- 4_Tables.do
|-- state_restriction_status.csv
|-- README.md
|-- output/
    |-- figures/
    |   |-- fig_predictors_x_snap.png|.pdf
    |   |-- fig_predictors_x_snap_descriptive.png|.pdf
    |-- tables/
    |   |-- Table1_Descriptives.xlsx
    |   |-- Table2_Main_Effects.xlsx
    |   |-- Table3_Predictors_by_SNAP.xlsx
    |-- derived/          # local only; not committed
    |-- logs/             # local only; not committed
`
