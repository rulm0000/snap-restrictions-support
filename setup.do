* setup.do
version 16.0
set more off

capture confirm global project_root
if _rc != 0 {
    global project_root "."
}

cd "$project_root"

* Raw inputs live one level above the repo (not committed)
global raw_parent "$project_root/.."
global raw_w2 "$raw_parent/University of Chicago Booth_SNAP Benefits Survey Tracker (W2)_RAW DATA_07.29.26_V01.xlsx"
global raw_w1 "$raw_parent/Numerator/Numerator_SNAP Restrictions_BL data_raw.csv"
global crosswalk "$project_root/state_restriction_status.csv"

global output "$project_root/output"
global data "$output/derived"
global tables "$output/tables"
global figures "$output/figures"
global logs "$output/logs"

capture mkdir "$output"
capture mkdir "$data"
capture mkdir "$tables"
capture mkdir "$figures"
capture mkdir "$logs"
