*==============================================================================*
* 01_prepare_data.do
* SNAP Wave 2 — prepare analysis file (prereg v10)
*==============================================================================*
clear all
set more off

* Paths (edit if relocating)
local root "C:\Users\culm\OneDrive - University of North Carolina at Chapel Hill\OUHSC Backup 6.26.23\Employee Folder\Stanford Data Analyst\SNAP"
local code "`root'\SNAP_support"
local out  "`code'\output"
capture mkdir "`out'"
capture mkdir "`out'\figures"
capture mkdir "`out'\logs"

capture log close _all
log using "`out'\logs\01_prepare_data.log", replace text

*------------------------------------------------------------------------------*
* 1. Import Wave 2
*------------------------------------------------------------------------------*
import excel using ///
    "`root'\University of Chicago Booth_SNAP Benefits Survey Tracker (W2)_RAW DATA_07.29.26_V01.xlsx", ///
    sheet("Raw Data") firstrow allstring clear

* Drop Qualtrics metadata / question-text row
keep if wave == "2"
count
display as text "Wave 2 respondents: " as result r(N)

*------------------------------------------------------------------------------*
* 2. Merge Wave 1 Q14 (soda overconsumption) by user_id
*    DEVIATION: Q14 empty in W2; use Dec 2025 Wave 1 response.
*------------------------------------------------------------------------------*
preserve
import delimited using ///
    "`root'\Numerator\Numerator_SNAP Restrictions_BL data_raw.csv", ///
    varnames(1) stringcols(_all) bindquote(strict) maxquotedrows(200) clear
keep if !missing(responseid) & substr(responseid, 1, 2) == "R_"
keep user_id q14
rename q14 q14_w1
duplicates drop user_id, force
tempfile w1_q14
save `w1_q14'
restore

merge m:1 user_id using `w1_q14', keep(master match) nogen
count if missing(q14_w1)
display as text "W2 rows missing W1 Q14: " as result r(N)

*------------------------------------------------------------------------------*
* 3. Outcome: support (Q2 early / Q13 late), 1-5
*------------------------------------------------------------------------------*
gen support = .
foreach q in Q2 Q13 {
    replace support = 1 if `q' == "Strongly oppose"
    replace support = 2 if `q' == "Somewhat oppose"
    replace support = 3 if `q' == "Neither oppose nor support"
    replace support = 4 if `q' == "Somewhat support"
    replace support = 5 if `q' == "Strongly support"
}
label define supportlbl ///
    1 "Strongly oppose" 2 "Somewhat oppose" 3 "Neither oppose nor support" ///
    4 "Somewhat support" 5 "Strongly support", replace
label values support supportlbl
label variable support "Support for SNAP soft-drink/candy restrictions (1-5)"

*------------------------------------------------------------------------------*
* 4. Moderator: SNAP participation (Q4). Don't Know -> missing (excluded).
*------------------------------------------------------------------------------*
gen snap = .
replace snap = 1 if Q4 == "Yes"
replace snap = 0 if Q4 == "No"
* Catch curly/smart apostrophe variants of Don't Know
replace snap = . if inlist(Q4, "Don't Know", "Don't Know", "Dont Know")
* Any remaining non Yes/No with text stays missing
label define snaplbl 0 "Non-SNAP" 1 "SNAP", replace
label values snap snaplbl
label variable snap "SNAP participation past 3 months (W2 Q4)"

tab Q4 snap, missing

*------------------------------------------------------------------------------*
* 5. Predictors (continuous per prereg v10)
*------------------------------------------------------------------------------*

* Perceived health risk of soda (Q3)
gen risk = .
replace risk = 1 if Q3 == "Not at all"
replace risk = 2 if Q3 == "Very little"
replace risk = 3 if Q3 == "Somewhat"
replace risk = 4 if Q3 == "Quite a bit"
replace risk = 5 if Q3 == "A great deal"
label variable risk "Perceived health risk of daily soda (1-5)"

* Embarrassment: Q5 (SNAP) / Q6 (non-SNAP)
gen embarrass = .
foreach q in Q5 Q6 {
    replace embarrass = 1 if `q' == "Never"
    replace embarrass = 2 if `q' == "Rarely"
    replace embarrass = 3 if `q' == "Sometimes"
    replace embarrass = 4 if `q' == "Often"
    replace embarrass = 5 if `q' == "Most or all of the time"
}
* Q5 "I did not pay..." stays missing
label variable embarrass "Felt/perceived judgment paying with SNAP (1-5)"

* Stigma items Q7 / Q8 -> mean stigma score
gen q7_num = .
replace q7_num = 1 if Q7 == "Strongly disagree"
replace q7_num = 2 if Q7 == "Somewhat disagree"
replace q7_num = 3 if Q7 == "Neither disagree nor agree"
replace q7_num = 4 if Q7 == "Somewhat agree"
replace q7_num = 5 if Q7 == "Strongly agree"

gen q8_num = .
replace q8_num = 1 if Q8 == "Strongly disagree"
replace q8_num = 2 if Q8 == "Somewhat disagree"
replace q8_num = 3 if Q8 == "Neither disagree nor agree"
replace q8_num = 4 if Q8 == "Somewhat agree"
replace q8_num = 5 if Q8 == "Strongly agree"

egen stigma = rowmean(q7_num q8_num)
label variable stigma "Perceived stigma (mean of Q7 disrespect + Q8 agency)"

* Descriptive reliability of stigma items (W2)
count if !missing(q7_num, q8_num)
alpha q7_num q8_num
spearman q7_num q8_num, stats(rho p obs)

* Overconsumption from Wave 1 Q14
gen overconsume = .
replace overconsume = 1 if q14_w1 == "Not at all"
replace overconsume = 2 if q14_w1 == "Somewhat"
replace overconsume = 3 if q14_w1 == "Mostly"
replace overconsume = 4 if q14_w1 == "Definitely"
label variable overconsume "Soda overconsumption (W1 Q14; 1-4)"

*------------------------------------------------------------------------------*
* 6. Covariates
*------------------------------------------------------------------------------*
foreach v in age_bucket gender ethnicity education income ///
    user_census_region_name has_children {
    encode `v', gen(cv_`v')
}

* State id for clustering
encode user_state_name, gen(state)

* Restriction status crosswalk
preserve
import delimited using "`code'\state_restriction_status.csv", ///
    varnames(1) stringcols(_all) clear
destring restriction_status_num, replace
tempfile xwalk
save `xwalk'
restore

rename user_state_name state_name
merge m:1 state_name using `xwalk', keep(master match) nogen
rename state_name user_state_name

destring restriction_status_num, replace force
label define restlbl ///
    1 "Currently implemented" ///
    2 "Previously implemented but vacated" ///
    3 "Adopted not yet implemented or vacated" ///
    4 "Not adopted", replace
label values restriction_status_num restlbl
label variable restriction_status_num "State SNAP restriction status (as of W2 fielding)"

tab restriction_status_num, missing
count if missing(restriction_status_num)
assert r(N) == 0

*------------------------------------------------------------------------------*
* 7. Analysis sample flags / Ns
*------------------------------------------------------------------------------*
gen analysis_ok = !missing(support, snap, risk, embarrass, stigma, overconsume, ///
    cv_age_bucket, cv_gender, cv_ethnicity, cv_education, cv_income, ///
    cv_user_census_region_name, cv_has_children, restriction_status_num, state)

count if !missing(snap)
local n_snap = r(N)
count if analysis_ok
local n_cc = r(N)

display as text "N with SNAP Yes/No (excl Don't Know): " as result `n_snap'
display as text "Complete-case analysis N: " as result `n_cc'

tab support snap if analysis_ok, missing
misstable summarize support snap risk embarrass stigma overconsume ///
    restriction_status_num if !missing(snap)

*------------------------------------------------------------------------------*
* 8. Save analysis file (local only; not committed to GitHub)
*------------------------------------------------------------------------------*
save "`out'\snap_w2_analysis.dta", replace
display as result "Saved: `out'\snap_w2_analysis.dta"

log close
