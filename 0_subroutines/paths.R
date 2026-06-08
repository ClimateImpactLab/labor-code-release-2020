# setup paths for R

# if first-time user, ensure these paths correspond to your code repo and input data
USER = Sys.getenv("USER")
REPO = paste0("/project/cil/home_dirs/", USER, "/repos")
ROOT_INT_DATA = "/project/cil/battuta_shares/gcp/estimation/labor/code_release_int_data"

# defined dynamically
DIR_REPO_LABOR = paste0(REPO,"/labor-code-release-2020")
DIR_REPO_POST_PROJ = paste0(REPO,"/post-projection-tools")

DIR_OUTPUT = paste0(REPO,"/output")

DIR_EXT_DATA = paste0(DIR_REPO_LABOR,"/data")
DIR_FIG = paste0(DIR_REPO_LABOR,"/figures")
DIR_OUTPUT = paste0(DIR_REPO_LABOR, "/output")

DIR_FIG = paste0(DIR_OUTPUT, "/figures")
DIR_STER = paste0(DIR_OUTPUT, "/ster")
DIR_RF = paste0(DIR_OUTPUT, "/rf")
DIR_TABLE = paste0(DIR_OUTPUT, "/tables")

