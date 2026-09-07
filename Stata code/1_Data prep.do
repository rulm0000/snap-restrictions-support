*1_Data prep

clear all
set more off

capture log close _all
log using "$logs/1_Data_Preparation.log", replace text
display "Step 1: Data Preparation"

import excel using "$raw_w2", sheet("Raw Data") firstrow allstring clear
keep if wave == "2"
count
display "Wave 2 respondents: " r(N)

* W1 Q14 (overconsumption) — deviation: not fielded in W2
preserve
import delimited using "$raw_w1", ///
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
display "W2 rows missing W1 Q14: " r(N)

* Outcome: support (Q2 early / Q13 late)
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
label variable support "Support for SNAP restrictions (1-5)"

* Moderator: SNAP (Don't Know -> missing)
gen snap = .
replace snap = 1 if Q4 == "Yes"
replace snap = 0 if Q4 == "No"
label define snaplbl 0 "Non-recipients" 1 "SNAP recipients", replace
label values snap snaplbl
label variable snap "SNAP participation"
tab Q4 snap, missing

* Psychological factors (continuous; prereg v10)
gen risk = .
replace risk = 1 if Q3 == "Not at all"
replace risk = 2 if Q3 == "Very little"
replace risk = 3 if Q3 == "Somewhat"
replace risk = 4 if Q3 == "Quite a bit"
replace risk = 5 if Q3 == "A great deal"
label variable risk "Perceived health risk of soda"

gen embarrass = .
foreach q in Q5 Q6 {
    replace embarrass = 1 if `q' == "Never"
    replace embarrass = 2 if `q' == "Rarely"
    replace embarrass = 3 if `q' == "Sometimes"
    replace embarrass = 4 if `q' == "Often"
    replace embarrass = 5 if `q' == "Most or all of the time"
}
label variable embarrass "Felt judged when paying with SNAP"

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
* Composite of Q7 (disrespect/stigma) and Q8 (loss of autonomy); displayed as paternalism
label variable stigma "Perceived paternalism of SNAP policies"
alpha q7_num q8_num
spearman q7_num q8_num, stats(rho p obs)

gen overconsume = .
replace overconsume = 1 if q14_w1 == "Not at all"
replace overconsume = 2 if q14_w1 == "Somewhat"
replace overconsume = 3 if q14_w1 == "Mostly"
replace overconsume = 4 if q14_w1 == "Definitely"
label variable overconsume "Self-reported soda overconsumption"

foreach v in age_bucket gender ethnicity education income ///
    user_census_region_name has_children {
    encode `v', gen(cv_`v')
}
encode user_state_name, gen(state)

* Race/ethnicity: White = 1 (regression reference); remaining groups follow
recode cv_ethnicity (5=1) (1=2) (2=3) (3=4) (4=5)
label define cv_ethnicity ///
    1 "White or Caucasian" ///
    2 "Asian" ///
    3 "Black or African American" ///
    4 "Hispanic or Latino" ///
    5 "Other", replace
label values cv_ethnicity cv_ethnicity

* Display labels for tables (encode keeps raw stub names otherwise)
label variable cv_age_bucket "Age group, years"
label variable cv_gender "Gender"
label variable cv_ethnicity "Race/ethnicity"
label variable cv_education "Education level"
label variable cv_income "Income group"
label variable cv_user_census_region_name "US Census Region"
label variable cv_has_children "Has children"

* Education: lowest → highest; Less than high school = 1 (reference)
recode cv_education (5=1) (4=2) (8=3) (6=4) (1=5) (2=6) (7=7) (3=8)
label define cv_education ///
    1 "Less than high school" ///
    2 "High school diploma or GED" ///
    3 "Trade or technical degree" ///
    4 "Some college or university" ///
    5 "2 year college degree" ///
    6 "4 year college degree" ///
    7 "Some graduate school" ///
    8 "Graduate degree", replace
label values cv_education cv_education

* Income: ascending; lowest (<$20k) = 1 (reference)
recode cv_income (7=1) (3=2) (4=3) (5=4) (6=5) (1=6) (2=7)
label define cv_income ///
    1 "<$20k" ///
    2 "$20k-40k" ///
    3 "$40k-60k" ///
    4 "$60k-80k" ///
    5 "$80k-100k" ///
    6 "$100k-125k" ///
    7 "$125k +", replace
label values cv_income cv_income

* State restriction status from revised PAP Table 1 (July 2026 waivers; USDA 2026d + state sites)
* Crosswalk also stores product-category indicators for documentation (not used in models)
preserve
import delimited using "$crosswalk", varnames(1) stringcols(_all) clear
destring restriction_status_num, replace
tempfile xwalk
save `xwalk'
restore

rename user_state_name state_name
merge m:1 state_name using `xwalk', keep(master match) nogen
rename state_name user_state_name

destring restriction_status_num, replace force
* Severity order: Not adopted (ref) → … → Currently implemented
* Crosswalk codes: 1=not adopted, 2=adopted not yet, 3=previously vacated, 4=currently implemented
label define restlbl ///
    1 "Not adopted" ///
    2 "Adopted not yet implemented or vacated" ///
    3 "Previously implemented but vacated" ///
    4 "Currently implemented", replace
label values restriction_status_num restlbl
label variable restriction_status_num "State SNAP restriction status"
tab restriction_status_num, missing
assert !missing(restriction_status_num)
assert inlist(restriction_status_num, 1, 2, 3, 4)

**#Survey weights (entropy balancing; Ron via Anna, 2026-09-05)
preserve
import delimited using "$weights_nonsnap", varnames(1) stringcols(1) clear
gen byte wt_stratum = 0
tempfile w_ns
save `w_ns'
import delimited using "$weights_snap", varnames(1) stringcols(1) clear
gen byte wt_stratum = 1
append using `w_ns'
drop if user_id == "0"
duplicates drop user_id, force
rename webal wt
label variable wt "Entropy-balancing survey weight"
label variable wt_stratum "Weight file stratum (0=non-SNAP purchase, 1=SNAP purchase)"
tempfile weights
save `weights'
restore

merge m:1 user_id using `weights', keep(master match) nogen
count if missing(wt)
display "Wave 2 rows with NO weight: " r(N)

* Winsorize at [1/3, 3] to match the parent paper's protocol
* (Allcott/Finkelstein/Grummon/Notowidigdo, Appendix E.1: "For downstream
* analyses, we winsorize weights at [1/3, 3]"). The delivered files are NOT
* winsorized: nothing falls below 1/3, but some weights exceed 3.
gen double wt_raw = wt
count if wt > 3 & !missing(wt)
display "Weights above 3 (winsorized down): " r(N)
count if wt < 1/3 & !missing(wt)
display "Weights below 1/3 (winsorized up): " r(N)
replace wt = min(max(wt, 1/3), 3)
label variable wt "Entropy-balancing survey weight (winsorized [1/3, 3])"
label variable wt_raw "Entropy-balancing survey weight (as delivered)"
summarize wt wt_raw
summarize wt, detail
tab wt_stratum snap, missing

gen analysis_ok = !missing(wt) & !missing(support, snap, risk, embarrass, stigma, overconsume, ///
    cv_age_bucket, cv_gender, cv_ethnicity, cv_education, cv_income, ///
    cv_user_census_region_name, cv_has_children, restriction_status_num, state)

count if !missing(snap)
display "N with SNAP Yes/No (excl Don't Know): " r(N)
count if analysis_ok
display "Complete-case analysis N: " r(N)
tab support snap if analysis_ok, missing

save "$Data/snap_w2_analysis.dta", replace
display "Saved $Data/snap_w2_analysis.dta"
log close
