# A MESS, NOT FINISHED WITH THIS SUCKER YET


#############
# INITIALIZE
#############

rm(list = ls())
library(dplyr)
library(ggplot2)
library(readr)
library(patchwork)
library(parallel)
library(testit)  
library(dplyr)
library(readr)
library(testit)
library(glue) 

SHARES = "/shares"
REPO = "/home/kschwarz/repos"
dir = glue("{SHARES}/gcp/estimation/labor/code_release_outputs/")

#############
# PLOT RFS
#############

rf = read_csv(glue("{dir}/ref/uninteracted_reg_comlohi.csv"))

plot_RF_hist = function(  
  df,
  names=c("low","high","comm")
  ) {

	reshape = function(
		name
		) {
		x = df %>% dplyr::select(
			temp, yhat_{name}, lowerci_high_, upperci_high_) %>%
    	mutate(risk = "high")
  	names(df_high) = c("temp", "yhat", "lower_ci", "upper_ci", "risk")

	}
  df_low = 
  	df %>% dplyr::select(temp, yhat_low, lowerci_low, upperci_low) %>%
    mutate(risk = "low")
  names(df_low) = c("temp", "yhat", "lower_ci", "upper_ci", "risk")
  
  
  
  plot_df = bind_rows(df_high, df_low) %>%
    mutate(order = ifelse(risk == "low", 1,2)) 
  
  plot_df$risk = reorder(plot_df$risk, plot_df$order)

  # Plot response function
  p = ggplot(df, aes(x = temp)) +
    geom_line(aes(group = risk, y = get(yvar)), size = 1) +
    geom_line(aes(group=Industry, color=Industry))+
    # geom_ribbon(aes(ymin = get(min_CI), ymax = get(max_CI)), alpha = 0.2) +
    theme_bw() + 
    geom_hline(yintercept=0, color = "red") + 
    theme(legend.position = "none", plot.title = element_text(size = 6)) + 
    ggtitle(paste0(FE,", Score is: ",score)) +
    ylab("Change in mins worked") +

   geom_ribbon(aes(ymin = get(min_CI), ymax = get(max_CI)), alpha = 0.2)



for(col in names) {
	= df %>% dplyr::select(temp, yhat_low_, lowerci_low_, upperci_low_) %>%
    mutate(risk = "low")
  	names(df_low) = c("temp", "yhat", "lower_ci", "upper_ci", "risk")

}

  
  p = ggplot(plot_df, aes(x = temp)) +
    geom_line(aes(y = yhat), size = 1) + 
    facet_wrap(vars(risk))  +    
    theme_bw() + 
    geom_hline(yintercept=0, color = "red") + 
    theme(legend.position = "none") + 
    ggtitle(
      paste0(FE,", ", FF, ifelse(FF=="splines",paste0(N_knots, " knots"),paste0( N_order, " order" )))) +
    ylab("Change in mins worked") + xlab("Temperature")
  
  if(SE == TRUE){  
    p = p +
         geom_ribbon(aes(ymin = lower_ci, ymax = upper_ci), alpha = 0.2 )
    SE_tag = "_with_SE"
  } else{
    SE_tag = ""
  }
    
  if(save== TRUE){
    folder_structure = list[["folder_structure"]]
    name = list[["name"]]
    print('saving')
    dir.create(paste0(output, folder_structure), 
               recursive = T, showWarnings = FALSE)
    output_pdf = paste0(output, folder_structure,"combined-risk_", name, SE_tag, ".pdf")
    ggsave(output_pdf, p)
    print(output_pdf)
  }
  else{
    return(p)
  }
}