## SNAP Restrictions Support - Analysis Code

This repository contains Stata and Python replication code and supporting files for the SNAP restrictions support analyses (AsPredicted pre-registration v10).
It documents the analysis pipeline and the generated outputs included in this repo.

### Purpose

Determine whether psychological predictors (self-reported soda overconsumption, perceived health risk of soda, perceived stigma of current SNAP policies, and embarrassment when paying with SNAP benefits) predict support for removing soft drinks and candy from SNAP-eligible food purchases, and whether these associations are moderated by SNAP participation.

### Analysis steps

- `1_Data_Preparation.do`
  - Imports and merges the survey waves, recodes the outcome and predictors, and defines the complete-case analysis sample. Perceived stigma of current SNAP policies is the average of two items assessing whether current SNAP policies are disrespectful toward SNAP participants and whether they take away personal freedom.
- `2_Main_Analysis.do`
  - Assesses multicollinearity, fits the linear regression of support on the predictors, SNAP participation, predictor by SNAP interactions, and covariates with standard errors clustered at the state level, runs Wald tests and simple effects, and exports the plot data.
- `3_Figures.py`
  - Draws the four-panel figures of support across predictor levels by SNAP participation, both model-adjusted and descriptive.
- `4_Tables.do`
  - Writes Table 1 (sample characteristics by SNAP), Table 2 (main-effects model), and Table 3 (simple slopes by SNAP).

### Repository layout

```
SNAP_support/
├── output/
│   ├── figures/
│   │   ├── fig_predictors_x_snap (.png, .pdf)
│   │   └── fig_predictors_x_snap_descriptive (.png, .pdf)
│   ├── tables/
│   │   ├── Table1_Descriptives.xlsx
│   │   ├── Table2_Main_Effects.xlsx
│   │   └── Table3_Predictors_by_SNAP.xlsx
│   ├── derived/
│   └── logs/
├── 0_Master.do
├── setup.do
├── 1_Data_Preparation.do
├── 2_Main_Analysis.do
├── 3_Figures.py
├── 4_Tables.do
├── state_restriction_status.csv
└── README.md
```

`output/derived/` and `output/logs/` are generated locally and are intentionally omitted from version control.

### Survey inputs

The raw Numerator survey files contain respondent-level data and are intentionally omitted from version control. To run the pipeline locally, place them one level above this folder:

- Wave 2 workbook (`University of Chicago Booth_SNAP Benefits Survey Tracker (W2)_RAW DATA...xlsx`)
- Wave 1 CSV used for the soda overconsumption item (`Numerator/Numerator_SNAP Restrictions_BL data_raw.csv`)

### Quick start

1. Open Stata.
2. `cd` into `SNAP_support/`.
3. Run:

```stata
do 0_Master.do
```

Figures are drawn in Python, so the machine also needs `pandas` and `matplotlib`.

### Notes

- Analyses are unweighted complete-case; weights were not available in the delivered files.
- Standard errors are clustered by state.
- State restriction status is a four-level covariate built from the Allcott et al. pre-analysis plan and the June 22, 2026 *Aragon v. Rollins* vacatur.
