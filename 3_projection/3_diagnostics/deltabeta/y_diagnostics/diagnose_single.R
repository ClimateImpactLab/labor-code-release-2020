library(tidyverse)
library(data.table)

fa = fread("/project/cil/home_dirs/egrenier/misc/labor/extracted_single/uninteracted_main_model-dec2025.csv") %>% 
  filter(year == 2099) %>% 
  dplyr::rename(fa = value)

ia = fread("/project/cil/home_dirs/egrenier/misc/labor/extracted_single/uninteracted_main_model-incadapt-dec2025.csv") %>% 
  filter(year == 2099) %>% 
  dplyr::rename(ia = value)

na = fread("/project/cil/home_dirs/egrenier/misc/labor/extracted_single/uninteracted_main_model-noadapt-dec2025.csv") %>% 
  filter(year == 2099) %>% 
  dplyr::rename(na = value)
 
diag = fa %>% left_join(ia) %>% left_join(na)

# different types of weird scenarios 
diag = diag %>% mutate(check = ifelse(ia < na, 1, 0))
diag = diag %>% mutate(check_pospos = ifelse((ia < na & ia > 0 & na > 0), 1, 0))
diag = diag %>% mutate(check_posneg = ifelse((ia < na & ia < 0 & na > 0), 1, 0))
diag = diag %>% mutate(check_negneg = ifelse((ia < na & ia < 0 & na < 0), 1, 0))

# Sum check totals
sum(diag$check) # total
sum(diag$check_pospos) # both positive
sum(diag$check_posneg) # inc adapt positive, no adapt negative
sum(diag$check_negneg) # both negative

# average difference
diag %>% 
  summarise(avg_diff_check = abs(mean((na-ia)[check == 1])),
            avg_diff_pospos = abs(mean((na-ia)[check_pospos == 1])),
            avg_diff_posneg = abs(mean((na-ia)[check_posneg == 1])),
            avg_diff_negneg = abs(mean((na-ia)[check_negneg == 1])))


# max difference
diag %>% 
  summarise(max_diff_check = max((na-ia)[check == 1]),
            max_diff_pospos = max((na-ia)[check_pospos == 1]),
            max_diff_posneg = max((na-ia)[check_posneg == 1]),
            max_diff_negneg = max((na-ia)[check_negneg == 1]))

diag %>% 
  summarise(sd_diff_check = sd((na-ia)[check == 1]),
            sd_diff_pospos = sd((na-ia)[check_pospos == 1]),
            sd_diff_posneg = sd((na-ia)[check_posneg == 1]),
            sd_diff_negneg = sd((na-ia)[check_negneg == 1]))
    