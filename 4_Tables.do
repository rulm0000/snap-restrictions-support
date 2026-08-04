* 4_Tables.do
* Table 1: descriptives by SNAP
* Table 1a: percent support (somewhat + strongly) by SNAP
* Table 2: main-effects model
* Table 3: simple slopes by SNAP + interaction p-values

clear all
set more off

capture confirm global tables
if _rc != 0 {
    global project_root "."
    do "setup.do"
}

capture log close _all
log using "$logs/4_Tables.log", replace text
display "Step 4: Tables"

use "$data/snap_w2_analysis.dta", clear
keep if analysis_ok
quietly count
local N = r(N)
quietly count if snap == 0
local N0 = r(N)
quietly count if snap == 1
local N1 = r(N)

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

quietly summarize support
local sd_y = r(sd)

*--------------------------------------------------------------------------
* Table 1: descriptives by SNAP
*--------------------------------------------------------------------------
putexcel set "$tables/Table1_Descriptives.xlsx", replace
putexcel A1 = ("Table 1. Sample characteristics by SNAP participation (N = `N')")
putexcel A2 = ("Variable")
putexcel B2 = ("Overall (N = `N')")
putexcel C2 = ("Non-SNAP (N = `N0')")
putexcel D2 = ("SNAP (N = `N1')")

local row = 3

* Same relative order as Table 2 predictors, then outcome
putexcel A`row' = ("Psychological predictors and outcome, mean (SD)")
local row = `row' + 1

foreach v in overconsume risk embarrass stigma support {
    local vlab : variable label `v'
    if "`vlab'" == "" local vlab "`v'"
    putexcel A`row' = ("`vlab'")

    quietly summarize `v'
    fmt_msd `r(mean)' `r(sd)'
    putexcel B`row' = ("`r(out)'")

    quietly summarize `v' if snap == 0
    fmt_msd `r(mean)' `r(sd)'
    putexcel C`row' = ("`r(out)'")

    quietly summarize `v' if snap == 1
    fmt_msd `r(mean)' `r(sd)'
    putexcel D`row' = ("`r(out)'")

    local row = `row' + 1
}

local row = `row' + 1
putexcel A`row' = ("Covariates, n (%)")
local row = `row' + 1

* Same covariate order as Table 2 ($covars); SNAP is column split, not a row.
* Level order is numeric ascending (= reference first for recoded factors).
local cats "cv_age_bucket cv_gender cv_ethnicity cv_education cv_income cv_user_census_region_name cv_has_children restriction_status_num"
foreach v of local cats {
    local vlab : variable label `v'
    if "`vlab'" == "" local vlab "`v'"
    putexcel A`row' = ("`vlab'")
    local row = `row' + 1

    quietly levelsof `v', local(levs)
    foreach lev of local levs {
        local levlab : label (`v') `lev'
        if "`levlab'" == "" local levlab "`lev'"
        putexcel A`row' = ("   `levlab'")

        quietly count if `v' == `lev'
        fmt_npct `r(N)' `N'
        putexcel B`row' = ("`r(out)'")

        quietly count if `v' == `lev' & snap == 0
        fmt_npct `r(N)' `N0'
        putexcel C`row' = ("`r(out)'")

        quietly count if `v' == `lev' & snap == 1
        fmt_npct `r(N)' `N1'
        putexcel D`row' = ("`r(out)'")

        local row = `row' + 1
    }
}

local note_row = `row' + 1
putexcel A`note_row' = ("Note. Complete-case analysis sample. Continuous variables reported as mean (SD); categorical covariates as n (% within column). Unweighted. Percentages may not sum to 100 because of rounding.")

display "Saved $tables/Table1_Descriptives.xlsx"

*--------------------------------------------------------------------------
* Table 1a: percent support by SNAP
*--------------------------------------------------------------------------
putexcel set "$tables/Table1a_Percent_Support.xlsx", replace
putexcel A1 = ("Table 1a. Percent support for SNAP soft-drink/candy restrictions, by SNAP participation (N = `N')")
putexcel A2 = ("Response")
putexcel B2 = ("Overall (N = `N')")
putexcel C2 = ("Non-SNAP (N = `N0')")
putexcel D2 = ("SNAP (N = `N1')")

local row = 3
putexcel A`row' = ("Support for removing soft drinks and candy from SNAP-eligible purchases, n (%)")
local row = `row' + 1

quietly levelsof support, local(slevs)
foreach lev of local slevs {
    local levlab : label (support) `lev'
    if "`levlab'" == "" local levlab "`lev'"
    putexcel A`row' = ("   `levlab'")

    quietly count if support == `lev'
    fmt_npct `r(N)' `N'
    putexcel B`row' = ("`r(out)'")

    quietly count if support == `lev' & snap == 0
    fmt_npct `r(N)' `N0'
    putexcel C`row' = ("`r(out)'")

    quietly count if support == `lev' & snap == 1
    fmt_npct `r(N)' `N1'
    putexcel D`row' = ("`r(out)'")

    local row = `row' + 1
}

local row = `row' + 1
putexcel A`row' = ("Somewhat or strongly support (sum), n (%)")

quietly count if inlist(support, 4, 5)
fmt_npct `r(N)' `N'
putexcel B`row' = ("`r(out)'")

quietly count if inlist(support, 4, 5) & snap == 0
fmt_npct `r(N)' `N0'
putexcel C`row' = ("`r(out)'")

quietly count if inlist(support, 4, 5) & snap == 1
fmt_npct `r(N)' `N1'
putexcel D`row' = ("`r(out)'")

local note_row = `row' + 2
putexcel A`note_row' = ("Note. Complete-case analysis sample. Cells are n (% within column). The summary row combines Somewhat support and Strongly support. Unweighted. Percentages may not sum to 100 because of rounding.")

display "Saved $tables/Table1a_Percent_Support.xlsx"

*--------------------------------------------------------------------------
* Table 2: main-effects model (no interactions)
*--------------------------------------------------------------------------
quietly regress support c.overconsume c.risk c.embarrass c.stigma i.snap ///
    $covars, vce(cluster state)
matrix T = r(table)
local names : colnames T
local r2 = e(r2)
local nclust = e(N_clust)

putexcel set "$tables/Table2_Main_Effects.xlsx", replace
putexcel A1 = ("Table 2. Main-effects model predicting support for SNAP soft-drink/candy restrictions (N = `N')")
putexcel A2 = ("Variable")
putexcel B2 = ("b (95% CI)")
putexcel C2 = ("Cohen's d")
putexcel D2 = ("p")

local row = 3
local prev ""
local j = 0
foreach nm of local names {
    local j = `j' + 1
    if "`nm'" == "_cons" continue

    local b = T[1,`j']
    local p = T[4,`j']
    local ll = T[5,`j']
    local ul = T[6,`j']
    local d = `b' / `sd_y'

    local pos = strpos("`nm'", ".")
    if `pos' > 0 {
        local lev = substr("`nm'", 1, `pos'-1)
        local v = substr("`nm'", `pos'+1, .)
        local base = strpos("`lev'", "b") > 0
        local levnum = subinstr(subinstr("`lev'", "b", "", .), "o", "", .)
        local vlab : variable label `v'
        if "`vlab'" == "" local vlab "`v'"
        local levlab : label (`v') `levnum'
        if "`levlab'" == "" local levlab "Level `levnum'"

        if "`v'" != "`prev'" {
            putexcel A`row' = ("`vlab'")
            local row = `row' + 1
            local prev "`v'"
        }
        putexcel A`row' = ("   `levlab'")
        if `base' {
            putexcel B`row' = ("reference")
            local row = `row' + 1
            continue
        }
    }
    else {
        local vlab : variable label `nm'
        if "`vlab'" == "" local vlab "`nm'"
        putexcel A`row' = ("`vlab'")
        local prev ""
    }

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
    putexcel B`row' = ("`bs' (`lls', `uls')")
    putexcel C`row' = ("`ds'")
    putexcel D`row' = ("`ps'")
    local row = `row' + 1
}

local note_row = `row' + 1
putexcel A`note_row' = ("Note. OLS regression of support (1 = Strongly oppose to 5 = Strongly support) on all predictors and covariates, without predictor×SNAP interactions. Standard errors clustered by state (`nclust' clusters). R-squared = " + string(`r2', "%9.3f") + ". Cohen's d = b / SD(support), the change in support in outcome SD units associated with a 1-unit increase in a continuous predictor or with membership in a listed category versus the reference. Unweighted; complete-case analysis. Multicollinearity was assessed with variance inflation factors before fitting (see 2_Main_Analysis log): all four psychological predictors and SNAP participation had VIF < 1.5; larger VIFs reflect multi-category covariate dummy sets (e.g., age).")

display "Saved $tables/Table2_Main_Effects.xlsx"

*--------------------------------------------------------------------------
* Table 3: simple slopes by SNAP + interaction p-values
*--------------------------------------------------------------------------
quietly regress support c.overconsume##i.snap c.risk##i.snap ///
    c.embarrass##i.snap c.stigma##i.snap $covars, vce(cluster state)

putexcel set "$tables/Table3_Predictors_by_SNAP.xlsx", replace
putexcel A1 = ("Table 3. Associations of psychological predictors with support for SNAP soft-drink/candy restrictions, by SNAP participation (N = `N')")
putexcel A2 = ("Predictor")
putexcel B2 = ("Non-SNAP")
putexcel E2 = ("SNAP")
putexcel H2 = ("p for interaction")
putexcel B3 = ("b (95% CI)")
putexcel C3 = ("Cohen's d")
putexcel D3 = ("p")
putexcel E3 = ("b (95% CI)")
putexcel F3 = ("Cohen's d")
putexcel G3 = ("p")

local preds "overconsume risk embarrass stigma"
local row = 4
foreach pred of local preds {
    local lab : variable label `pred'
    if "`lab'" == "" local lab "`pred'"

    putexcel A`row' = ("`lab'")

    quietly testparm c.`pred'#i.snap
    fmt_p `r(p)'
    putexcel H`row' = ("`r(out)'")

    quietly margins snap, dydx(`pred')
    matrix M = r(table)

    local b0 = M[1,1]
    local ll0 = M[5,1]
    local ul0 = M[6,1]
    local p0 = M[4,1]
    local d0 = `b0' / `sd_y'
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
    putexcel B`row' = ("`b0s' (`ll0s', `ul0s')")
    putexcel C`row' = ("`d0s'")
    putexcel D`row' = ("`p0s'")

    local b1 = M[1,2]
    local ll1 = M[5,2]
    local ul1 = M[6,2]
    local p1 = M[4,2]
    local d1 = `b1' / `sd_y'
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
    putexcel E`row' = ("`b1s' (`ll1s', `ul1s')")
    putexcel F`row' = ("`d1s'")
    putexcel G`row' = ("`p1s'")

    local row = `row' + 1
}

local note_row = `row' + 1
putexcel A`note_row' = ("Note. Coefficients are simple slopes (change in support per 1-unit increase in the predictor) from an OLS model with continuous predictors, SNAP participation, predictor×SNAP interactions, and covariates (age, gender, ethnicity, education, income, census region, children in household, state restriction status). Cohen's d = b / SD(support), the change in support in outcome SD units per 1-unit increase in the predictor. Standard errors clustered by state. Outcome: support for removing soft drinks and candy from SNAP-eligible purchases (1 = Strongly oppose to 5 = Strongly support). Unweighted. Complete-case analysis.")

display "Saved $tables/Table3_Predictors_by_SNAP.xlsx"

capture erase "$tables/Table2_Predictors_by_SNAP.xlsx"
capture erase "$tables/Table3_Main_Effects.xlsx"

log close
