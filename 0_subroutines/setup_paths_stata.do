* set up paths for stata programs
* the user needs to determine where the repo is located
* and where the large raw data files are
global ROOT_REPO = "/home/liruixue/repos"
global ROOT_INT_DATA = "/shares/gcp"

* generate the rest of the paths according to the first two
global DIR_OUTPUT = "${ROOT_REPO}/output"
global DIR_EXT_DATA = "${ROOT_REPO}/data"

global DIR_REPO_LABOR = "${ROOT_REPO}/labor-code-release-2020"

global DIR_EXT_DATA = "${ROOT_REPO}/data"
global DIR_FIG = "${DIR_EXT_DATA}/figures"

global DIR_STER = "${DIR_EXT_DATA}/sters"
