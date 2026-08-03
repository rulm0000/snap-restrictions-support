*==============================================================================*
* 02_main_analysis.do
* SNAP Wave 2 — prereg v10 main model (unweighted; state-clustered SEs)
*==============================================================================*
clear all
set more off

local root "C:\Users\culm\OneDrive - University of North Carolina at Chapel Hill\OUHSC Backup 6.26.23\Employee Folder\Stanford Data Analyst\SNAP"
local code "`root'\SNAP_support"
local out  "`code'\output"

capture log close _all
log using "`out'\logs\02_main_analysis.log", replace text

use "`out'\snap_w2_analysis.dta", clear
keep if analysis_ok
count
display as text "Analysis N: " as result r(N)

* Covariate block (restriction status as factor)
global covars "i.cv_age_bucket i.cv_gender i.cv_ethnicity i.cv_education i.cv_income i.cv_user_census_region_name i.cv_has_children i.restriction_status_num"

*------------------------------------------------------------------------------*
* Multicollinearity check (linear terms; interactions omitted)
*------------------------------------------------------------------------------*
quietly regress support c.overconsume c.risk c.embarrass c.stigma ///
    i.snap $covars
estat vif

*------------------------------------------------------------------------------*
* Primary model: continuous predictors x SNAP; cluster by state
*------------------------------------------------------------------------------*
regress support c.overconsume##i.snap c.risk##i.snap ///
    c.embarrass##i.snap c.stigma##i.snap $covars, vce(cluster state)

estimates store main

*------------------------------------------------------------------------------*
* Moderation screen: Wald tests of each predictor x SNAP block
*------------------------------------------------------------------------------*
testparm c.overconsume#i.snap
testparm c.risk#i.snap
testparm c.embarrass#i.snap
testparm c.stigma#i.snap

*------------------------------------------------------------------------------*
* Simple effects: slope of each predictor within SNAP / Non-SNAP
*------------------------------------------------------------------------------*
margins snap, dydx(overconsume)
margins snap, dydx(risk)
margins snap, dydx(embarrass)
margins snap, dydx(stigma)

*------------------------------------------------------------------------------*
* Predicted marginal means by predictor level x SNAP + figures
*------------------------------------------------------------------------------*

* Overconsumption (1-4)
margins snap, at(overconsume=(1(1)4))
marginsplot, xdimension(overconsume) ///
    title("Adjusted mean support by soda overconsumption x SNAP") ///
    ytitle("Predicted support (1-5)") ///
    xtitle("Self-reported soda overconsumption (W1 Q14)")
graph export "`out'\figures\fig_overconsume.png", replace width(1200)

* Perceived risk (1-5)
margins snap, at(risk=(1(1)5))
marginsplot, xdimension(risk) ///
    title("Adjusted mean support by perceived risk x SNAP") ///
    ytitle("Predicted support (1-5)") ///
    xtitle("Perceived health risk of soda")
graph export "`out'\figures\fig_risk.png", replace width(1200)

* Embarrassment (1-5)
margins snap, at(embarrass=(1(1)5))
marginsplot, xdimension(embarrass) ///
    title("Adjusted mean support by embarrassment x SNAP") ///
    ytitle("Predicted support (1-5)") ///
    xtitle("Felt/perceived judgment when paying with SNAP")
graph export "`out'\figures\fig_embarrass.png", replace width(1200)

* Stigma mean (plot at 1, 1.5, ..., 5)
margins snap, at(stigma=(1(0.5)5))
marginsplot, xdimension(stigma) ///
    title("Adjusted mean support by perceived stigma x SNAP") ///
    ytitle("Predicted support (1-5)") ///
    xtitle("Perceived stigma of current SNAP policies (Q7+Q8 mean)")
graph export "`out'\figures\fig_stigma.png", replace width(1200)

display as result "02_main_analysis.do finished."
log close
