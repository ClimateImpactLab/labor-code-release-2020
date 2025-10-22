*********************
*	STATA PATHS
*********************
* set up paths for stata programs
* the user needs to determine where the repo is located
* and where the large raw data files are

* set internal data path
*gl ROOT_INT_DATA = "${shares_path}/gcp/estimation/labor/code_release_int_data"
gl ROOT_INT_DATA = "/project/cil/kupe_shares/CIL_temp_storage/labor/code_release_int_data"
* set repo path
gl ROOT_REPO = "/project/cil/home_dirs/maiqi/repos"
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


