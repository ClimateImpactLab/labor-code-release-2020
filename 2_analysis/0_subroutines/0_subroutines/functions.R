# Reshapes a dataset from wide to long to allow for plotting.
# @Param name : the suffix of the variable (default is 'low')
# @Param df   : the dataframe to be reshaped
# @Param vars : the list of variables to be reshaped
reshape = function(name, df=rf, vars=c("yhat","lowerci","upperci")) {
  
  varlist = c("temp")
  for(v in vars){
    varlist = c(varlist, glue("{v}_{name}"))
  }
  
  x = df %>% dplyr::select(
    unlist(varlist)) %>% 
    mutate(risk = glue("{name}"))
  
  names(x) = 
    c(c("temp", vars), "risk")
  
  return(x)
} 



