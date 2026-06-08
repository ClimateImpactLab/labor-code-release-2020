# set up paths for python scripts
import getpass
username = getpass.getuser()

ROOT_REPO = f"/project/cil/home_dirs/{username}/repos"
ROOT_INT_DATA = "/project/cil/battuta_shares/gcp/estimation/labor/code_release_int_data"

DIR_EXT_DATA = ROOT_REPO + "/data"
DIR_REPO_LABOR = ROOT_REPO + "/labor-code-release-2020"
DIR_OUTPUT = DIR_REPO_LABOR + "/output"
DIR_FIG = DIR_OUTPUT + "/figures"
DIR_STER = DIR_OUTPUT + "/ster"
DIR_RF = DIR_OUTPUT + "/rf"
DIR_TABLE = DIR_OUTPUT + "/tables"

DIR_REPO_POST_PROJ = ROOT_REPO + "/post-projection-tools"






