# load csv files ----------------------------------------------------------

special_education_data <- read_csv("~/VCE_AI_TOOL/data/sources/Virginia-Department-of-Education/2021-2022_Special_Education_Child_Count.csv")
fips_lookup <- read_csv("~/VCE_AI_TOOL/data/outcome/virginia_localities.csv")

# clean dataset ----------------------------------------------------------

# add fips codes from virginia localities csv
updated_data <- special_education_data %>% 
  # convert division name to lowercase for consistency
  mutate(Division_Lower = str_to_lower(`Division Name`)) %>%
  
  # left join to combine both csvs
  left_join(
    fips_lookup, 
    by = c("Division_Lower" = "alias")
  ) %>%
  
  # drop unused columns
  select(-c("Division_Lower", "official_name", "locality_type", "Division Number")) %>% 
  drop_na(fips_code) %>%
  
  # relocate new column
  relocate(fips_code, .after = "Division Name")

# write csv
write_csv(updated_data, here("data/outcome/Virginia-Department-of-Education/2021-2022_Special_Education_Child_Count.csv"))