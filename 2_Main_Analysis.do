* 2_Main_Analysis.do
* Prereg v10 model: continuous predictors x SNAP; state-clustered SEs

clear all
set more off

capture confirm global data
if _rc != 0 {
    global project_root "."
    do "setup.do"
}

capture log close _all
log using "$logs/2_Main_Analysis.log", replace text
display "Step 2: Main Analysis"

use "$data/snap_w2_analysis.dta", clear
keep if analysis_ok
count
display "Analysis N: " r(N)

* Factor bases (level 1): White; Less than HS; lowest income; Not adopted
global covars "i.cv_age_bucket i.cv_gender ib1.cv_ethnicity ib1.cv_education ib1.cv_income i.cv_user_census_region_name i.cv_has_children ib1.restriction_status_num"

quietly regress support c.overconsume c.risk c.embarrass c.stigma i.snap $covars
estat vif

regress support c.overconsume##i.snap c.risk##i.snap ///
    c.embarrass##i.snap c.stigma##i.snap $covars, vce(cluster state)
estimates store main

testparm c.overconsume#i.snap
testparm c.risk#i.snap
testparm c.embarrass#i.snap
testparm c.stigma#i.snap

margins snap, dydx(overconsume)
margins snap, dydx(risk)
margins snap, dydx(embarrass)
margins snap, dydx(stigma)

*--------------------------------------------------------------------------
* Plot data for 3_Figures.py
*--------------------------------------------------------------------------
tempfile adata mtmp p1 p2 p3
save `adata'

quietly margins snap, at(overconsume=(1(1)4)) saving(`mtmp', replace)
use `mtmp', clear
gen panel = "overconsume"
gen x = _at1
gen snapg = _m1
keep panel x snapg _margin _ci_lb _ci_ub
rename (_margin _ci_lb _ci_ub) (est lo hi)
save `p1'

use `adata', clear
quietly regress support c.overconsume##i.snap c.risk##i.snap ///
    c.embarrass##i.snap c.stigma##i.snap $covars, vce(cluster state)
quietly margins snap, at(risk=(1(1)5)) saving(`mtmp', replace)
use `mtmp', clear
gen panel = "risk"
gen x = _at3
gen snapg = _m1
keep panel x snapg _margin _ci_lb _ci_ub
rename (_margin _ci_lb _ci_ub) (est lo hi)
save `p2'

use `adata', clear
quietly regress support c.overconsume##i.snap c.risk##i.snap ///
    c.embarrass##i.snap c.stigma##i.snap $covars, vce(cluster state)
quietly margins snap, at(embarrass=(1(1)5)) saving(`mtmp', replace)
use `mtmp', clear
gen panel = "embarrass"
gen x = _at4
gen snapg = _m1
keep panel x snapg _margin _ci_lb _ci_ub
rename (_margin _ci_lb _ci_ub) (est lo hi)
save `p3'

use `adata', clear
quietly regress support c.overconsume##i.snap c.risk##i.snap ///
    c.embarrass##i.snap c.stigma##i.snap $covars, vce(cluster state)
quietly margins snap, at(stigma=(1(0.5)5)) saving(`mtmp', replace)
use `mtmp', clear
gen panel = "stigma"
gen x = _at5
gen snapg = _m1
keep panel x snapg _margin _ci_lb _ci_ub
rename (_margin _ci_lb _ci_ub) (est lo hi)

append using `p1'
append using `p2'
append using `p3'
export delimited using "$data/plotdata_adjusted.csv", nolabel replace

use `adata', clear
collapse (mean) est=support (sd) sd=support (count) n=support, by(overconsume snap)
gen panel = "overconsume"
rename (overconsume snap) (x snapg)
save `p1', replace

use `adata', clear
collapse (mean) est=support (sd) sd=support (count) n=support, by(risk snap)
gen panel = "risk"
rename (risk snap) (x snapg)
save `p2', replace

use `adata', clear
collapse (mean) est=support (sd) sd=support (count) n=support, by(embarrass snap)
gen panel = "embarrass"
rename (embarrass snap) (x snapg)
save `p3', replace

use `adata', clear
gen stigma_bin = round(stigma, 0.5)
collapse (mean) est=support (sd) sd=support (count) n=support, by(stigma_bin snap)
gen panel = "stigma"
rename (stigma_bin snap) (x snapg)

append using `p1'
append using `p2'
append using `p3'
gen se = sd / sqrt(n)
gen lo = est - invttail(n-1, 0.025) * se
gen hi = est + invttail(n-1, 0.025) * se
keep panel x snapg est lo hi n
export delimited using "$data/plotdata_descriptive.csv", nolabel replace

log close
