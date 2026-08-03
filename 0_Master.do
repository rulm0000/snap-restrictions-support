clear all
set more off
macro drop _all

if "`c(username)'" == "ag" {
	global project_root "/Users/ag/Documents/GitHub/SNAP_support"
}
else if "`c(username)'" == "culm" {
	global project_root "."
}
else {
	global project_root "."
}

do "setup.do"

display "Starting Analysis Pipeline..."

display "Running 1_Data_Preparation.do..."
do "1_Data_Preparation.do"

display "Running 2_Main_Analysis.do..."
do "2_Main_Analysis.do"

display "Running 3_Figures.py..."
shell python "3_Figures.py"

display "Running 4_Tables.do..."
do "4_Tables.do"

display "Analysis Pipeline Complete!"
