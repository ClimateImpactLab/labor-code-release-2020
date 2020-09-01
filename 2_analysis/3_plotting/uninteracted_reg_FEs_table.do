*****************
*	INITIALIZE
*****************

* get functions and paths
run "/home/`c(username)'/repos/labor-code-release-2020/0_subroutines/paths.do"
run "${DIR_REPO_LABOR}/2_analysis/0_subroutines/functions.do"

* select dataset and output folder
loc rf_folder 		"${DIR_RF}/uninteracted_reg_FEs"  
loc table_folder 	"${DIR_TABLE}"

* other selections
global fe_list fe_adm0_y fe_adm0_my fe_adm0_wk fe_adm3_my 

***********************************
*	GENERATE LATEX TABLE
***********************************

local i = 0

foreach fe in $fe_list {

	import delim "`rf_folder'/uninteracted_reg_FE_`fe'_table_values.csv", clear
	rename * *_`fe'
	rename temp temp

	if `i' == 0 {
		* initialize with first model
		tempfile data
		save `data'
	}
	else {
		* add columns for next models
		merge 1:1 temp using `data', nogen
		save `data', replace
	}

	* save colnames for convert_table function
	gl low_categories $low_categories low_`fe'
	gl high_categories $high_categories high_`fe'

	loc ++i

}

convert_table, categories("$low_categories $high_categories")

dataout, save("`table_folder'/uninteracted_reg_FEs") tex replace
   
