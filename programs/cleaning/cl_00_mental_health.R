# load csv files ----------------------------------------------------------

depression_data <- read_csv("~/VCE_AI_TOOL/data/sources/Mental-Health-America/Depression_County_Map_Full_Data.csv")
fips_lookup <- read_csv("~/VCE_AI_TOOL/data/outcome/virginia_localities.csv")

# clean dataset ----------------------------------------------------------

updated_data <- depression_data %>%
  # remove unused columns
  select(-c("County, State", "2021 population", "2022 population", "Calc Total Depression Responses", "Calc Positive Severe Depression", "# per 100K")) %>% 
  
    # dataset has missing population columns for some years so calculate each
  mutate(
    Population_2020 = round((`2020 Positive Severe Depression` / `# per 100K 2020`) * 100000),
    Population_2021 = round((`2021 Positive Severe Depression` / `# per 100K 2021`) * 100000),
    Population_2022 = round((`2022 Positive Severe Depression` / `# per 100K 2022`) * 100000),
    Population_2023 = round((`2023 Positive Severe Depression` / `# per 100K 2023`) * 100000),
    Population_2024 = round((`2024 Positive Severe Depression` / `# per 100K 2024`) * 100000),
    Population_2025 = round((`2025 Positive Severe Depression` / `# per 100K 2025`) * 100000)
  ) %>% 
  
  # add fips codes from virginia localities csv
  mutate(County_Lower = str_to_lower(`County Name`)) %>%
  left_join(
    fips_lookup, 
    by = c("County_Lower" = "alias")
  ) %>%
  # remove the columns from virginia localities csv
  select(-c("County_Lower", "official_name", "locality_type")) %>% 
  relocate(fips_code, .after = "County Name")

# add fips code for fairfax county and roanoke manually (since the names don't match for this dataset and virginia localities csv)
updated_data[which(updated_data$`County Name` == "Fairfax"), "fips_code"] <- 51059

updated_data[which(updated_data$`County Name` == "Roanoke"), "fips_code"] <- 51161

# write csv
write_csv(updated_data, here("data/outcome/Mental-Health-America/Depression_County_Map_Full_Data.csv"))