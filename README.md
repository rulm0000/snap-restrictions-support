# Replication files for "Psychological factors associated with support for SNAP restrictions"

### Description
This repository includes the Stata and Python code and folder structure to reproduce the analysis of the manuscript "Psychological factors associated with support for SNAP restrictions".

We surveyed panelists in the Numerator Consumer Panel, a national panel of US households, in December 2025 (prior to any restrictions being implemented) and July 2026. We report data from July 2026 unless otherwise noted. We regressed support for restricting soda and candy from SNAP-eligible purchases on four psychological factors (perceived health risk of soda, self-reported soda overconsumption, feeling judged when using SNAP, perceived paternalism of SNAP policies), SNAP recipient status, and their interactions, adjusting for demographic covariates. We pre-registered the analysis plan before receiving the data (AsPredicted #303941).

### Data availability
The survey data and sample weights are not included in this repository. The Numerator purchase-panel data are proprietary; release of the survey data is under discussion with the study team. The state SNAP restriction crosswalk is included. The survey and its weights are described in Allcott H, Finkelstein A, Grummon A, Notowidigdo MJ. The Effects of SNAP Sugary Drink Restrictions on Consumption and Welfare. NBER Working Paper 35659; 2026.

### Instructions to reproduce the analysis:
Open `Stata code/0_Analysis Parent File.do`, customize the user file paths, and run it. It calls every other file in sequence and saves all outputs to the Results folders.

Analyses used Stata version 19.5. The Python files require `pandas`, `matplotlib`, `Pillow`, `openpyxl`, and `python-docx`.

*****
Folder tree:

```bash
AJPH-snap-restrictions-support
├── README.md
├── Stata code
│   ├── 0_Analysis Parent File.do
│   ├── 1_Data prep.do
│   ├── 2_Main analysis.do
│   ├── 3_Tables.do
│   ├── 3.1_Style tables.py
│   ├── 4_Figures.py
│   └── 5_Supplement.py
└── Project folders-files
    ├── Data
    │   └── state_restriction_status.csv
    └── Results
        ├── Tables
        ├── Figures
        └── Logs
```
*****
