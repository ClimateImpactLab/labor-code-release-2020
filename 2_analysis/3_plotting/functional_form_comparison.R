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
library(data.table)
library(plyr)
library(tidyverse)
library(tidyr)
source("/home/liruixue/projection_repos/post-projection-tools/mapping/imgcat.R")
source('~/repos/labor-code-release-2020/0_subroutines/paths.R')
source('~/repos/labor-code-release-2020/2_analysis/0_subroutines/functions.R')

# set macro: nochn, wchn
reg = "wchn"

#############
# GET DATA
#############

bins = read_csv(
		glue("{DIR_RF}/uninteracted_bins/",
		"uninteracted_bins_{reg}_full_response.csv"))

poly_2 = read_csv(
		glue("{DIR_RF}/uninteracted_polynomials/",
		"uninteracted_polynomials_{reg}_2_full_response.csv"))

poly_3 = read_csv(
		glue("{DIR_RF}/uninteracted_polynomials/",
		"uninteracted_polynomials_{reg}_3_full_response.csv"))

poly_4 = read_csv(
		glue("{DIR_RF}/uninteracted_polynomials/",
		"uninteracted_polynomials_{reg}_4_full_response.csv"))

# because of my poor naming choices, this if statement
# manually selects which spline to plot (w or w/o China)
if(reg == "nochn") {
  message("Plotting no_chn spline.")
  spline = read_csv(
      glue("{DIR_RF}/uninteracted_reg_comlohi/",
      "uninteracted_reg_comlohi_full_response.csv"))
} else if(reg == "wchn") {
  message("Plotting w_chn spline.")
  spline = read_csv(
    glue("{DIR_RF}/uninteracted_reg_w_chn/",
    "uninteracted_reg_w_chn_full_response.csv"))
}

forms = list(bins, poly_2, poly_3, poly_4, spline)
names(forms) = list("bins", "poly_2", "poly_3", "poly_4", "spline")

#######################
# RESHAPE DATA & MERGE
#######################

# select columns we want for plotting
forms = lapply(forms,
                 select,
                 c(yhat_low,yhat_high,temp))

# this silly forloop exists because R is a terrible
# language and I am v sad about it
for(i in 1:length(forms)) {
  
  # reshape, rename each dataframa
  forms[[i]] = mclapply(list("low","high"),
                        df = forms[[i]],
                        reshape,
                        vars=c("yhat"),
                        mc.cores=2) %>%
    rbindlist(use.names=TRUE) %>%
    plyr::rename(
      c("yhat"=glue("{names(forms)[[i]]}")))
}

# merge dataframes for plotting
df = Reduce(function(x,y) merge(x = x, y = y, by = c("temp","risk")), 
       forms)

####################
# PLOT - SINGLE PANEL
####################

# p = ggplot(df, aes(x=temp)) +
#   geom_line(aes(y = bins, color = "bins")) + 
#   geom_line(aes(y = poly_2, color = "poly_2")) +
#   geom_line(aes(y = poly_3, color = "poly_3")) + 
#   geom_line(aes(y = poly_4, color = "poly_4")) + 
#   geom_line(aes(y = spline, color = "spline")) +
#   facet_wrap(~ risk) +
#   ggtitle("Functional Form Comparison") +
#   ylab("Change in mins worked") + xlab("Temperature (C)") +
#   scale_color_manual(values = 
#                        c("darkred", "steelblue",
#                          "orange", "violet", "darkgreen"))  
# 
# pdf(glue('{DIR_FIG}/functional_form_comparison_{reg}.pdf'))
# plot(p)
# dev.off()

####################
# PLOT - MULTI PANEL
####################

df_long <- gather(df, form, value, poly_2:spline, factor_key=TRUE)

df_high = df_long %>% dplyr::filter(risk == "high")
df_low =  df_long %>% dplyr::filter(risk == "low")

a = ggplot(df_high, aes(x=temp, color=form)) +
  geom_line(aes(y = value)) +
  geom_line(aes(y = bins, color = "bins")) +
  facet_wrap(~ form) +
  ggtitle("Functional Form Comparison: High Risk") +
  ylab("Change in mins worked") + xlab("Temperature (C)") +
  theme(legend.position = "none") +
  scale_color_manual(values = 
                       c("dimgrey", "steelblue",
                         "orange", "violet", "darkgreen"))

b = ggplot(df_low, aes(x=temp, color=form)) +
  geom_line(aes(y = value)) +
  geom_line(aes(y = bins, color = "bins")) +
  facet_wrap(~ form) +
  ggtitle("Functional Form Comparison: Low Risk") +
  ylab("Change in mins worked") + xlab("Temperature (C)") +
  theme(legend.position = "none") +
  scale_color_manual(values = 
                       c("dimgrey", "steelblue",
                         "orange", "violet", "darkgreen"))

pdf(glue('{DIR_FIG}/functional_form/functional_form_comparison_{reg}_high.pdf'))
plot(a)
dev.off()

pdf(glue('{DIR_FIG}/functional_form/functional_form_comparison_{reg}_low.pdf'))
plot(b)
dev.off()



# limit the top and bottom bin also to width of 3
a = ggplot(df_high %>%filter(temp >= -3, temp <= 45 ), aes(x=temp, color=form)) +
  geom_line(aes(y = value)) +
  geom_line(aes(y = bins, color = "bins")) +
  facet_grid(~ form) +
  ggtitle("Functional Form Comparison: High Risk") +
  ylab("Change in mins worked") + xlab("Temperature (C)") +
  theme(legend.position = "none") +
  scale_color_manual(values = 
                       c("dimgrey", "steelblue",
                         "orange", "violet", "darkgreen"))+
  theme_bw() +
  theme(panel.grid.major = element_blank(), 
  panel.grid.minor = element_blank(),
  panel.background = element_blank())

b = ggplot(df_low %>%filter(temp >= -3, temp <= 45), aes(x=temp, color=form)) +
  geom_line(aes(y = value)) +
  geom_line(aes(y = bins, color = "bins")) +
  facet_grid(~ form) +
  ggtitle("Functional Form Comparison: Low Risk") +
  ylab("Change in mins worked") + xlab("Temperature (C)") +
  theme(legend.position = "none") +
  scale_color_manual(values = 
                       c("dimgrey", "steelblue",
                         "orange", "violet", "darkgreen"))+
  theme_bw() +
  theme(panel.grid.major = element_blank(), 
  panel.grid.minor = element_blank(),
  panel.background = element_blank())

ggsave(a, file = glue('{DIR_FIG}/functional_form/functional_form_comparison_{reg}_high_short_ends.pdf'),
   width = 16, height = 4)
ggsave(b, file = glue('{DIR_FIG}/functional_form/functional_form_comparison_{reg}_low_short_ends.pdf'),
   width = 16, height = 4)


# plot with points in the middle of the bin instead of lines


# limit the top and bottom bin also to width of 3
a = ggplot(df_high %>%filter(temp >= -3, temp <= 45 ), aes(x=temp, color=form)) +
  geom_line(aes(y = value)) + 
  geom_point(aes(y = bins), data = df_high %>% filter(temp >= -3, temp <= 45, temp %% 3 ==0)) +
  geom_line(aes(y = bins), data = df_high %>% filter(temp >= -3, temp <= 45, temp %% 3 ==0)) +
  facet_grid(~ form) +
  ggtitle("Functional Form Comparison: High Risk") +
  ylab("Change in mins worked") + xlab("Temperature (C)") +
  theme(legend.position = "none") +
  scale_color_manual(values = 
                       c("dimgrey", "steelblue",
                         "orange", "violet", "darkgreen"))+
  theme_bw() +
  theme(panel.grid.major = element_blank(), 
  panel.grid.minor = element_blank(),
  panel.background = element_blank())

b = ggplot(df_low %>%filter(temp >= -3, temp <= 45 ), aes(x=temp, color=form)) +
  geom_line(aes(y = value)) + 
  geom_point(aes(y = bins), data = df_low %>% filter(temp >= -3, temp <= 45, temp %% 3 ==0)) +
  geom_line(aes(y = bins), data = df_low %>% filter(temp >= -3, temp <= 45, temp %% 3 ==0)) +
  facet_grid(~ form) +
  ggtitle("Functional Form Comparison: Low Risk") +
  ylab("Change in mins worked") + xlab("Temperature (C)") +
  theme(legend.position = "none") +
  scale_color_manual(values = 
                       c("dimgrey", "steelblue",
                         "orange", "violet", "darkgreen"))+
  theme_bw() +
  theme(panel.grid.major = element_blank(), 
  panel.grid.minor = element_blank(),
  panel.background = element_blank())

ggsave(a, file = glue('{DIR_FIG}/functional_form/functional_form_comparison_{reg}_high_point.pdf'),
  width = 16, height = 4)
ggsave(b, file = glue('{DIR_FIG}/functional_form/functional_form_comparison_{reg}_low_point.pdf'),
  width = 16, height = 4)



###############
# EXPORT DATA 
################

write_csv(df, glue('{DIR_RF}/functional_form_comparison_{reg}.csv'))
