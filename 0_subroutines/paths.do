*********************
*	STATA PATHS
*********************
* set up paths for stata programs
* the user needs to determine where the repo is located
* and where the large raw data files are


* for use on our internal remote servers
* remove this once the data has been shifted to an external location
if "`c(hostname)'" == "battuta" {
	gl shares_path "/mnt/sacagawea_shares"
}
else {
	gl shares_path "/shares"
}

* set internal data path
gl ROOT_INT_DATA = "${shares_path}/gcp/estimation/labor/code_release_int_data"

* set repo path
gl ROOT_REPO = "/home/`c(username)'/repos"
gl DIR_REPO_LABOR = "${ROOT_REPO}/labor-code-release-2020"

* set logs path
gl DIR_LOG = "${DIR_REPO_LABOR}/logs"

* set external data path
gl DIR_EXT_DATA = "${DIR_REPO_LABOR}/data"

* set output folder paths
gl DIR_OUTPUT = "${DIR_REPO_LABOR}/output"

gl DIR_FIG = "${DIR_OUTPUT}/figures"

gl DIR_STER = "${DIR_OUTPUT}/ster"

gl DIR_RF = "${DIR_OUTPUT}/rf"

gl DIR_TABLE = "${DIR_OUTPUT}/table"


