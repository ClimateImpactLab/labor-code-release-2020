*****************
*	INITIALIZE
*****************

* get functions and paths
run "/home/`c(username)'/repos/labor-code-release-2020/0_subroutines/paths.do"
run "${DIR_REPO_LABOR}/2_analysis/0_subroutines/functions.do"

* select dataset and output folder
loc rf_folder 		"${DIR_RF}/uninteracted_reg_comlohi"  
loc table_folder 	"${DIR_TABLE}"

***********************************
*	GENERATE LATEX TABLE
***********************************

import delim "`rf_folder'/uninteracted_reg_comlohi_table_values.csv", clear

convert_table, categories("comm low high")

dataout, save("`table_folder'/uninteracted_reg_comlohi") tex replace
