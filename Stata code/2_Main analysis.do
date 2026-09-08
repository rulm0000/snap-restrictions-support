*2_Main analysis

clear all
set more off

capture log close _all
log using "$logs/2_Main_Analysis.log", replace text
display "Step 2: Main Analysis"

use "$Data/snap_w2_analysis.dta", clear
keep if analysis_ok
count
display "Analysis N: " r(N)

* Mean-center predictors (analysis-sample means) for model interpretability
foreach v in overconsume risk embarrass stigma {
    quietly summarize `v' [aweight=wt]
    scalar m_`v' = r(mean)
    display "Mean `v' = " m_`v'
    gen double `v'_c = `v' - m_`v'
    local lab : variable label `v'
    label variable `v'_c "`lab' (mean-centered)"
}

* Factor bases (level 1): White; Less than HS; lowest income; Not adopted
* Age uses the last level (65+) as the base rather than level 1 (18-20, n=8);
* the model is identical either way, but contrasts against an 8-person cell
* have uninformative CIs
global covars "ib(last).cv_age_bucket i.cv_gender ib1.cv_ethnicity ib1.cv_education ib1.cv_income i.cv_user_census_region_name i.cv_has_children ib1.restriction_status_num"

quietly regress support c.overconsume_c c.risk_c c.embarrass_c c.stigma_c i.snap $covars [pweight=wt]
estat vif

regress support c.overconsume_c##i.snap c.risk_c##i.snap ///
    c.embarrass_c##i.snap c.stigma_c##i.snap $covars [pweight=wt], vce(cluster state)
estimates store main

testparm c.overconsume_c#i.snap
testparm c.risk_c#i.snap
testparm c.embarrass_c#i.snap
testparm c.stigma_c#i.snap

margins snap, dydx(overconsume_c)
margins snap, dydx(risk_c)
margins snap, dydx(embarrass_c)
margins snap, dydx(stigma_c)

**#Plot data for 4_Figures.py
tempfile adata mtmp p1 p2 p3
save `adata'

capture program drop margins_to_plot
program define margins_to_plot
    * args: panelname mean_val centered_varname
    args panel mean_val cvar cvarlab
    gen double x = .
    foreach v of varlist _at* {
        capture confirm numeric variable `v'
        if _rc continue
        local lab : variable label `v'
        if "`lab'" == "`cvar'" | "`lab'" == "`cvarlab'" {
            replace x = `v' + `mean_val'
        }
    }
    quietly count if missing(x)
    if r(N) {
        * Fallback (needed under pweight, where margins labels _at# with the
        * variable's LABEL rather than its name): the at() variable is the only
        * numeric _at# column that is fully observed and takes >1 value.
        foreach v of varlist _at* {
            capture confirm numeric variable `v'
            if _rc continue
            quietly summarize `v'
            if r(N) == _N & r(min) < r(max) {
                replace x = `v' + `mean_val'
            }
        }
    }
    quietly count if missing(x)
    if r(N) {
        display as error "margins_to_plot: no usable _at column for `cvar'"
        exit 198
    }
    gen panel = "`panel'"
    gen snapg = _m1
    keep panel x snapg _margin _ci_lb _ci_ub
    rename (_margin _ci_lb _ci_ub) (est lo hi)
end

local oc_ats
forvalues x = 1/4 {
    local oc_ats `oc_ats' `=`x' - m_overconsume'
}
quietly margins snap, at(overconsume_c=(`oc_ats')) saving(`mtmp', replace)
use `mtmp', clear
margins_to_plot overconsume `=m_overconsume' overconsume_c
save `p1'

use `adata', clear
quietly regress support c.overconsume_c##i.snap c.risk_c##i.snap ///
    c.embarrass_c##i.snap c.stigma_c##i.snap $covars [pweight=wt], vce(cluster state)
local risk_ats
forvalues x = 1/5 {
    local risk_ats `risk_ats' `=`x' - m_risk'
}
quietly margins snap, at(risk_c=(`risk_ats')) saving(`mtmp', replace)
use `mtmp', clear
margins_to_plot risk `=m_risk' risk_c
save `p2'

use `adata', clear
quietly regress support c.overconsume_c##i.snap c.risk_c##i.snap ///
    c.embarrass_c##i.snap c.stigma_c##i.snap $covars [pweight=wt], vce(cluster state)
local emb_ats
forvalues x = 1/5 {
    local emb_ats `emb_ats' `=`x' - m_embarrass'
}
quietly margins snap, at(embarrass_c=(`emb_ats')) saving(`mtmp', replace)
use `mtmp', clear
margins_to_plot embarrass `=m_embarrass' embarrass_c
save `p3'

use `adata', clear
quietly regress support c.overconsume_c##i.snap c.risk_c##i.snap ///
    c.embarrass_c##i.snap c.stigma_c##i.snap $covars [pweight=wt], vce(cluster state)
local stig_ats
forvalues i = 0/8 {
    local x = 1 + 0.5 * `i'
    local stig_ats `stig_ats' `=`x' - m_stigma'
}
quietly margins snap, at(stigma_c=(`stig_ats')) saving(`mtmp', replace)
use `mtmp', clear
margins_to_plot stigma `=m_stigma' stigma_c

append using `p1'
append using `p2'
append using `p3'
export delimited using "$Data/plotdata_adjusted.csv", nolabel replace

* Descriptive means use original (uncentered) predictor scales
use `adata', clear
collapse (mean) est=support (sd) sd=support (count) n=support [aweight=wt], by(overconsume snap)
gen panel = "overconsume"
rename (overconsume snap) (x snapg)
save `p1', replace

use `adata', clear
collapse (mean) est=support (sd) sd=support (count) n=support [aweight=wt], by(risk snap)
gen panel = "risk"
rename (risk snap) (x snapg)
save `p2', replace

use `adata', clear
collapse (mean) est=support (sd) sd=support (count) n=support [aweight=wt], by(embarrass snap)
gen panel = "embarrass"
rename (embarrass snap) (x snapg)
save `p3', replace

use `adata', clear
gen stigma_bin = round(stigma, 0.5)
collapse (mean) est=support (sd) sd=support (count) n=support [aweight=wt], by(stigma_bin snap)
gen panel = "stigma"
rename (stigma_bin snap) (x snapg)

append using `p1'
append using `p2'
append using `p3'
gen se = sd / sqrt(n)
gen lo = est - invttail(n-1, 0.025) * se
gen hi = est + invttail(n-1, 0.025) * se
keep panel x snapg est lo hi n
export delimited using "$Data/plotdata_descriptive.csv", nolabel replace

log close
