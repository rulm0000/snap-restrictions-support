*3_Tables

clear all
set more off

capture log close _all
log using "$logs/3_Tables.log", replace text
display "Step 3: Tables"

use "$Data/snap_w2_analysis.dta", clear
keep if analysis_ok
quietly count
local N = r(N)
quietly count if snap == 0
local N0 = r(N)
quietly count if snap == 1
local N1 = r(N)

* Weighted totals (for weighted percentages) and a support indicator
quietly summarize wt, meanonly
local W = r(sum)
quietly summarize wt if snap == 0, meanonly
local W0 = r(sum)
quietly summarize wt if snap == 1, meanonly
local W1 = r(sum)
gen byte supp45 = inlist(support, 4, 5)

capture program drop fmt_npct_w
program define fmt_npct_w, rclass
    args n wsum wdenom
    local pct = 100 * `wsum' / `wdenom'
    return local out = string(`n') + " (" + trim(string(`pct', "%9.1f")) + ")"
end

* Factor bases (level 1): White; Less than HS; lowest income; Not adopted
global covars "i.cv_age_bucket i.cv_gender ib1.cv_ethnicity ib1.cv_education ib1.cv_income i.cv_user_census_region_name i.cv_has_children ib1.restriction_status_num"

capture program drop fmt_b
program define fmt_b, rclass
    args x
    return local out = trim(string(`x', "%9.2f"))
end

capture program drop fmt_p
program define fmt_p, rclass
    args p
    if `p' < 0.001 {
        return local out "<0.001"
    }
    else if `p' < 0.01 {
        return local out = trim(string(`p', "%9.3f"))
    }
    else if `p' >= 0.045 & `p' < 0.055 {
        * Three decimals near the 0.05 threshold so rounding never hides which side
        return local out = trim(string(`p', "%9.3f"))
    }
    else {
        return local out = trim(string(`p', "%9.2f"))
    }
end

capture program drop fmt_msd
program define fmt_msd, rclass
    args m s
    return local out = trim(string(`m', "%9.2f")) + " (" + trim(string(`s', "%9.2f")) + ")"
end

capture program drop fmt_npct
program define fmt_npct, rclass
    args n denom
    local pct = 100 * `n' / `denom'
    return local out = string(`n') + " (" + trim(string(`pct', "%9.1f")) + ")"
end

* Race/ethnicity display order A–Z (model reference White=1 unchanged)
capture program drop eth_display_levels
program define eth_display_levels, rclass
    return local levs "2 3 4 5 1"
end

quietly summarize support [aweight=wt]
local sd_y = r(sd)
foreach v in overconsume risk embarrass stigma snap {
    quietly summarize `v' [aweight=wt]
    local sd_`v' = r(sd)
}

**#Table 1: descriptives by SNAP
putexcel set "$tables/Table1_Descriptives.xlsx", replace
putexcel A1 = ("Table 1. Sample characteristics by SNAP participation, complete-case analysis (N = `N')")
putexcel A2 = ("Variable")
putexcel B2 = ("Overall (N = `N')")
putexcel C2 = ("Non-recipients (N = `N0')")
putexcel D2 = ("SNAP recipients (N = `N1')")

local row = 3

putexcel A`row' = ("Psychological factors and outcome, mean (SD)")
local row = `row' + 1

foreach v in overconsume risk embarrass stigma support {
    local vlab : variable label `v'
    if "`vlab'" == "" local vlab "`v'"
    putexcel A`row' = ("   `vlab'")

    quietly summarize `v' [aweight=wt]
    fmt_msd `r(mean)' `r(sd)'
    putexcel B`row' = ("`r(out)'")

    quietly summarize `v' [aweight=wt] if snap == 0
    fmt_msd `r(mean)' `r(sd)'
    putexcel C`row' = ("`r(out)'")

    quietly summarize `v' [aweight=wt] if snap == 1
    fmt_msd `r(mean)' `r(sd)'
    putexcel D`row' = ("`r(out)'")

    local row = `row' + 1
}

local row = `row' + 1
putexcel A`row' = ("Covariates, n (%)")
local row = `row' + 1

local cats "cv_age_bucket cv_gender cv_ethnicity cv_education cv_income cv_user_census_region_name cv_has_children restriction_status_num"
foreach v of local cats {
    local vlab : variable label `v'
    if "`vlab'" == "" local vlab "`v'"
    putexcel A`row' = ("`vlab'")
    local row = `row' + 1

    if "`v'" == "cv_ethnicity" {
        eth_display_levels
        local levs "`r(levs)'"
    }
    else {
        quietly levelsof `v', local(levs)
    }
    foreach lev of local levs {
        local levlab : label (`v') `lev'
        if "`levlab'" == "" local levlab "`lev'"
        putexcel A`row' = ("   `levlab'")

        quietly count if `v' == `lev'
        local nlev = r(N)
        quietly summarize wt if `v' == `lev', meanonly
        fmt_npct_w `nlev' `r(sum)' `W'
        putexcel B`row' = ("`r(out)'")

        quietly count if `v' == `lev' & snap == 0
        local nlev0 = r(N)
        quietly summarize wt if `v' == `lev' & snap == 0, meanonly
        fmt_npct_w `nlev0' `r(sum)' `W0'
        putexcel C`row' = ("`r(out)'")

        quietly count if `v' == `lev' & snap == 1
        local nlev1 = r(N)
        quietly summarize wt if `v' == `lev' & snap == 1, meanonly
        fmt_npct_w `nlev1' `r(sum)' `W1'
        putexcel D`row' = ("`r(out)'")

        local row = `row' + 1
    }
}

display "Saved $tables/Table1_Descriptives.xlsx"

**#Table 1a: % somewhat/strongly supporting, by covariate level and SNAP
capture program drop wpct_se
program define wpct_se, rclass
    * Weighted % supporting + linearized SE (state-clustered where estimable)
    syntax , IFcond(string)
    capture quietly mean supp45 [pweight=wt] if `ifcond', vce(cluster state)
    if _rc != 0 {
        capture quietly mean supp45 [pweight=wt] if `ifcond'
    }
    if _rc != 0 {
        return local out "—"
        exit
    }
    matrix M = r(table)
    local pct = 100 * M[1,1]
    local se  = 100 * M[2,1]
    return local out = trim(string(`pct', "%9.1f")) + " (" + trim(string(`se', "%9.1f")) + ")"
end

capture program drop put_pct_support
program define put_pct_support
    args row var lev
    wpct_se, ifcond("`var' == `lev'")
    putexcel B`row' = ("`r(out)'")
    wpct_se, ifcond("`var' == `lev' & snap == 0")
    putexcel C`row' = ("`r(out)'")
    wpct_se, ifcond("`var' == `lev' & snap == 1")
    putexcel D`row' = ("`r(out)'")
end

putexcel set "$tables/Table1a_Percent_Support.xlsx", replace
putexcel A1 = ("Table 1a. Percent somewhat or strongly supporting SNAP soda and candy restrictions, by subgroup and SNAP participation, complete-case analysis (N = `N')")
putexcel A2 = ("Variable")
putexcel B2 = ("Overall, % (SE)")
putexcel C2 = ("Non-recipients, % (SE)")
putexcel D2 = ("SNAP recipients, % (SE)")

local row = 3
putexcel A`row' = ("Total sample")
wpct_se, ifcond("1")
putexcel B`row' = ("`r(out)'")
wpct_se, ifcond("snap == 0")
putexcel C`row' = ("`r(out)'")
wpct_se, ifcond("snap == 1")
putexcel D`row' = ("`r(out)'")
local row = `row' + 2

putexcel A`row' = ("Covariates")
local row = `row' + 1

local cats "cv_age_bucket cv_gender cv_ethnicity cv_education cv_income cv_user_census_region_name cv_has_children restriction_status_num"
foreach v of local cats {
    local vlab : variable label `v'
    if "`vlab'" == "" local vlab "`v'"
    putexcel A`row' = ("`vlab'")
    local row = `row' + 1

    if "`v'" == "cv_ethnicity" {
        eth_display_levels
        local levs "`r(levs)'"
    }
    else {
        quietly levelsof `v', local(levs)
    }
    foreach lev of local levs {
        local levlab : label (`v') `lev'
        if "`levlab'" == "" local levlab "`lev'"
        putexcel A`row' = ("   `levlab'")
        put_pct_support `row' `v' `lev'
        local row = `row' + 1
    }
}

display "Saved $tables/Table1a_Percent_Support.xlsx"

**#One analysis model (Tables 2 and 3): mean-centered psychological factors
foreach v in overconsume risk embarrass stigma {
    quietly summarize `v' [aweight=wt]
    gen double `v'_c = `v' - r(mean)
    local lab : variable label `v'
    label variable `v'_c "`lab' (mean-centered)"
}

quietly regress support c.overconsume_c##i.snap c.risk_c##i.snap ///
    c.embarrass_c##i.snap c.stigma_c##i.snap $covars [pweight=wt], vce(cluster state)
estimates store main
matrix T = r(table)
local names : colnames T
local r2 = e(r2)
local nclust = e(N_clust)
local r2s = trim(string(`r2', "%9.3f"))

**#Table 2: coefficients from the interaction model (interactions omitted)
capture program drop t2_put_stats
program define t2_put_stats
    args row b ll ul d p
    fmt_b `b'
    local bs = r(out)
    fmt_b `ll'
    local lls = r(out)
    fmt_b `ul'
    local uls = r(out)
    fmt_p `p'
    local ps = r(out)
    fmt_b `d'
    local ds = r(out)
    if `p' < 0.05 {
        putexcel B`row' = ("`bs' (`lls', `uls')"), bold
        putexcel C`row' = ("`ds'"), bold
        putexcel D`row' = ("`ps'"), bold
    }
    else {
        putexcel B`row' = ("`bs' (`lls', `uls')")
        putexcel C`row' = ("`ds'")
        putexcel D`row' = ("`ps'")
    }
end

putexcel set "$tables/Table2_Regression.xlsx", replace
putexcel A1 = ("Table 2. Linear regression of support for SNAP soda and candy restrictions, complete-case analysis (N = `N'; R-squared = `r2s')")
putexcel A2 = ("Variable")
putexcel B2 = ("b (95% CI)"), italic
putexcel C2 = ("Standardized effect"), italic
putexcel D2 = ("p-value"), italic

* Forest-plot export (standardized effects + CI); same order as Table 2,
* except psychological factors are re-sorted positive-first before export
tempfile forest
tempname pf
postfile `pf' str80 group str120 modality byte is_ref double d double d_lo double d_hi using `forest', replace

local row = 3

* --- SNAP participation (first) ---
local prev ""
local j = 0
foreach nm of local names {
    local j = `j' + 1
    if "`nm'" == "_cons" continue
    if strpos("`nm'", "#") > 0 continue
    * Keep only snap factor terms (e.g., 0b.snap, 1.snap)
    if !(strpos("`nm'", ".snap") > 0) continue

    local b = T[1,`j']
    local p = T[4,`j']
    local ll = T[5,`j']
    local ul = T[6,`j']

    local pos = strpos("`nm'", ".")
    local lev = substr("`nm'", 1, `pos'-1)
    local v = substr("`nm'", `pos'+1, .)
    local levnum = subinstr(subinstr("`lev'", "b", "", .), "o", "", .)
    local vlab : variable label `v'
    if "`vlab'" == "" local vlab "`v'"
    local levlab : label (`v') `levnum'
    if "`levlab'" == "" local levlab "Level `levnum'"

    if "`v'" != "`prev'" {
        putexcel A`row' = ("`vlab'"), bold
        local row = `row' + 1
        local prev "`v'"
    }

    if missing(`p') | missing(`ll') {
        putexcel A`row' = ("   `levlab'")
        putexcel B`row' = ("reference")
        post `pf' ("`vlab'") ("`levlab'") (1) (0) (0) (0)
        local row = `row' + 1
        continue
    }

    putexcel A`row' = ("   `levlab'")
    quietly count if `v' == `levnum'
    local plev = r(N) / `N'
    local sd_x = sqrt(`plev' * (1 - `plev'))
    local d = `b' * `sd_x' / `sd_y'
    local d_lo = `ll' * `sd_x' / `sd_y'
    local d_hi = `ul' * `sd_x' / `sd_y'
    t2_put_stats `row' `b' `ll' `ul' `d' `p'
    post `pf' ("`vlab'") ("`levlab'") (0) (`d') (`d_lo') (`d_hi')
    local row = `row' + 1
}

* --- Psychological factors (average marginal effects across SNAP groups) ---
putexcel A`row' = ("Psychological factors")
local row = `row' + 1

foreach pred in overconsume_c risk_c embarrass_c stigma_c {
    quietly margins, dydx(`pred')
    matrix M = r(table)
    local b = M[1,1]
    local p = M[4,1]
    local ll = M[5,1]
    local ul = M[6,1]
    local pred0 = subinstr("`pred'", "_c", "", 1)
    local vlab : variable label `pred0'
    if "`vlab'" == "" local vlab "`pred0'"
    putexcel A`row' = ("   `vlab'")
    quietly summarize `pred'
    local sd_x = r(sd)
    local d = `b' * `sd_x' / `sd_y'
    local d_lo = `ll' * `sd_x' / `sd_y'
    local d_hi = `ul' * `sd_x' / `sd_y'
    t2_put_stats `row' `b' `ll' `ul' `d' `p'
    post `pf' ("Psychological factors") ("`vlab'") (0) (`d') (`d_lo') (`d_hi')
    local row = `row' + 1
}

* --- Covariates ---
putexcel A`row' = ("Covariates")
local row = `row' + 1

local prev ""
local j = 0
foreach nm of local names {
    local j = `j' + 1
    if "`nm'" == "_cons" continue
    if strpos("`nm'", "#") > 0 continue
    if strpos("`nm'", ".snap") > 0 continue
    * Skip continuous psychological factors (already written)
    if inlist("`nm'", "overconsume_c", "risk_c", "embarrass_c", "stigma_c") continue
    if strpos("`nm'", ".") == 0 continue

    local b = T[1,`j']
    local p = T[4,`j']
    local ll = T[5,`j']
    local ul = T[6,`j']

    local pos = strpos("`nm'", ".")
    local lev = substr("`nm'", 1, `pos'-1)
    local v = substr("`nm'", `pos'+1, .)
    local levnum = subinstr(subinstr("`lev'", "b", "", .), "o", "", .)
    local vlab : variable label `v'
    if "`vlab'" == "" local vlab "`v'"
    local levlab : label (`v') `levnum'
    if "`levlab'" == "" local levlab "Level `levnum'"

    if "`v'" != "`prev'" {
        putexcel A`row' = ("`vlab'"), bold
        local row = `row' + 1
        local prev "`v'"
    }

    if missing(`p') | missing(`ll') {
        putexcel A`row' = ("   `levlab'")
        putexcel B`row' = ("reference")
        post `pf' ("`vlab'") ("`levlab'") (1) (0) (0) (0)
        local row = `row' + 1
        continue
    }

    putexcel A`row' = ("   `levlab'")
    quietly count if `v' == `levnum'
    local plev = r(N) / `N'
    local sd_x = sqrt(`plev' * (1 - `plev'))
    local d = `b' * `sd_x' / `sd_y'
    local d_lo = `ll' * `sd_x' / `sd_y'
    local d_hi = `ul' * `sd_x' / `sd_y'
    t2_put_stats `row' `b' `ll' `ul' `d' `p'
    post `pf' ("`vlab'") ("`levlab'") (0) (`d') (`d_lo') (`d_hi')
    local row = `row' + 1
}

postclose `pf'
preserve
use `forest', clear
* Positive association first within psychological factors (8/17 meeting):
* risk, overconsumption, embarrassment, paternalism
gen double _ord = _n
quietly replace _ord = _ord - 1.5 if group == "Psychological factors" & ///
    modality == "Perceived health risk of soda"
sort _ord
drop _ord
export delimited using "$Data/plotdata_standardized_effects.csv", replace
display "Saved $Data/plotdata_standardized_effects.csv"
restore

display "Saved $tables/Table2_Regression.xlsx"

**#Table 3: simple slopes by SNAP + interaction p-values (same model)
estimates restore main

putexcel set "$tables/Table3_Predictors_by_SNAP.xlsx", replace
putexcel A1 = ("Table 3. Associations of psychological factors with support for SNAP soda and candy restrictions, by SNAP participation, complete-case analysis (N = `N')")
putexcel A2 = ("Factor")
putexcel B2 = ("Non-recipients")
putexcel E2 = ("SNAP recipients")
putexcel H2 = ("p for interaction"), italic
putexcel B3 = ("b (95% CI)"), italic
putexcel C3 = ("β"), italic
putexcel D3 = ("p-value"), italic
putexcel E3 = ("b (95% CI)"), italic
putexcel F3 = ("β"), italic
putexcel G3 = ("p-value"), italic

local preds "overconsume_c risk_c embarrass_c stigma_c"
local row = 4
foreach pred of local preds {
    local pred0 = subinstr("`pred'", "_c", "", 1)
    local lab : variable label `pred0'
    if "`lab'" == "" local lab "`pred0'"

    putexcel A`row' = ("`lab'")

    quietly testparm c.`pred'#i.snap
    local pint = r(p)
    fmt_p `pint'
    if `pint' < 0.05 {
        putexcel H`row' = ("`r(out)'"), bold
    }
    else {
        putexcel H`row' = ("`r(out)'")
    }

    quietly margins snap, dydx(`pred')
    matrix M = r(table)

    * Common SD(predictor) so Non-recipient vs SNAP recipient d's differ only by slope
    local d0 = M[1,1] * `sd_`pred0'' / `sd_y'
    local b0 = M[1,1]
    local ll0 = M[5,1]
    local ul0 = M[6,1]
    local p0 = M[4,1]
    fmt_b `b0'
    local b0s = r(out)
    fmt_b `ll0'
    local ll0s = r(out)
    fmt_b `ul0'
    local ul0s = r(out)
    fmt_p `p0'
    local p0s = r(out)
    fmt_b `d0'
    local d0s = r(out)
    if `p0' < 0.05 {
        putexcel B`row' = ("`b0s' (`ll0s', `ul0s')"), bold
        putexcel C`row' = ("`d0s'"), bold
        putexcel D`row' = ("`p0s'"), bold
    }
    else {
        putexcel B`row' = ("`b0s' (`ll0s', `ul0s')")
        putexcel C`row' = ("`d0s'")
        putexcel D`row' = ("`p0s'")
    }

    local b1 = M[1,2]
    local ll1 = M[5,2]
    local ul1 = M[6,2]
    local p1 = M[4,2]
    local d1 = `b1' * `sd_`pred0'' / `sd_y'
    fmt_b `b1'
    local b1s = r(out)
    fmt_b `ll1'
    local ll1s = r(out)
    fmt_b `ul1'
    local ul1s = r(out)
    fmt_p `p1'
    local p1s = r(out)
    fmt_b `d1'
    local d1s = r(out)
    if `p1' < 0.05 {
        putexcel E`row' = ("`b1s' (`ll1s', `ul1s')"), bold
        putexcel F`row' = ("`d1s'"), bold
        putexcel G`row' = ("`p1s'"), bold
    }
    else {
        putexcel E`row' = ("`b1s' (`ll1s', `ul1s')")
        putexcel F`row' = ("`d1s'")
        putexcel G`row' = ("`p1s'")
    }

    local row = `row' + 1
}

display "Saved $tables/Table3_Predictors_by_SNAP.xlsx"

capture erase "$tables/Table2_Main_Effects.xlsx"
capture erase "$tables/Table2_Predictors_by_SNAP.xlsx"
capture erase "$tables/Table3_Main_Effects.xlsx"

display "Styling Excel tables..."

display "Drawing standardized-effects forest figure..."

log close
