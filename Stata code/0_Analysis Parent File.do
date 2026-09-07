*Analysis Parent File

*No user changes are needed. The repository location is detected automatically
*from Stata's working directory. Known users are listed as a fallback below.
	*To find your username, use the following command: [display "`c(username)'"] 

*Locate the repository root by walking up from the working directory
global Root ""
local candidate "`c(pwd)'"
forvalues i = 1/6 {
	capture confirm file "`candidate'/Stata code/0_Analysis Parent File.do"
	if _rc == 0 {
		global Root "`candidate'"
		continue, break
	}
	local candidate "`candidate'/.."
}

*Fallback - user file paths, used only if the automatic detection above fails
*(for example, if Stata's working directory is outside the repository).
*Replace xxx with your Stata username and yyy with the repository location.
if "$Root" == "" {
	if "`c(username)'" =="xxx" {
		global Root "/yyy/SNAP_support"
	}
}

if "$Root" == "" {
	display as error "Could not locate the repository from `c(pwd)'"
	display as error "Set Stata's working directory to the repository folder and run again."
	exit 601
}

global Data 	"$Root/Project folders-files/Data"
global Results  "$Root/Project folders-files/Results"
global Code 	"$Root/Stata code"
display "Repository root: $Root"

*Output folders
global tables 	"$Results/Tables"
global figures 	"$Results/Figures"
global logs 	"$Results/Logs"
capture mkdir "$tables"
capture mkdir "$figures"
capture mkdir "$logs"

*Restricted-access inputs - not distributed with this repository
*See the Data availability section of the README
global raw_w2 			"$Data/University of Chicago Booth_SNAP Benefits Survey Tracker (W2)_RAW DATA_07.29.26_V01.xlsx"
global raw_w1 			"$Data/Numerator_SNAP Restrictions_BL data_raw.csv"
global weights_nonsnap 	"$Data/R_survey_ebal_final_weights_nonsnap_2025.csv"
global weights_snap 	"$Data/R_survey_ebal_final_weights_snap_2025.csv"

*State SNAP restriction crosswalk - included in this repository
global crosswalk 		"$Data/state_restriction_status.csv"

*************
*Run the codes below:
*Each analysis file writes its own log to $logs, so these are called with
*[do] rather than [run] - [run] suppresses output and would leave the logs empty.

*Data cleaning and preparation
do "$Code/1_Data prep.do"

*Analysis - adjusted margins for the figures
do "$Code/2_Main analysis.do"

*Analysis - manuscript and supplement tables
do "$Code/3_Tables.do"
shell python "$Code/3.1_Style tables.py" "$Results"

*Figures
shell python "$Code/4_Figures.py" "$Data" "$Results"

*Supplement
shell python "$Code/5_Supplement.py" "$Results"
