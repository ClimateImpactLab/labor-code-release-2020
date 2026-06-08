*********************
*	STATA PATHS
*********************
* set up paths for stata programs
* the user needs to determine where the repo is located
* and where the large raw data files are

* set repo path
gl ROOT_REPO = "/project/cil/home_dirs/`c(username)'/repos"
gl DIR_REPO_LABOR = "${ROOT_REPO}/labor-code-release-2020"

* set internal data path
gl ROOT_INT_DATA = "/project/cil/battuta_shares/gcp/estimation/labor/code_release_int_data"

* set output folder paths
gl DIR_OUTPUT = "${DIR_REPO_LABOR}/output"
gl DIR_LOG = "${DIR_OUTPUT}/logs"
gl DIR_STER = "${DIR_OUTPUT}/ster"
gl DIR_FIG = "${DIR_OUTPUT}/figures"
gl DIR_RF = "${DIR_OUTPUT}/rf"
gl DIR_TABLE = "${DIR_OUTPUT}/tables"


