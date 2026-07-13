my_data <- read_excel("data/sources/Virginia-Department-of-Education/2022-2025_State_Testing.xlsx")
write.csv(my_data, "data/sources/Virginia-Department-of-Education/20222-2025_State_Testing.csv", row.names = FALSE)

state_testing_data <- read_csv("data/sources/Virginia-Department-of-Education/2022-2025_State_Testing.csv")
fips_lookup <- read_csv("data/outcome/virginia_localities.csv")

clean_data <- state_testing_data %>% 
  select(-c("Level", "Div Num", "Sch Num")) %>% 
  # convert division name to lowercase for consistency
  mutate(Div_Lower = str_to_lower(`Div Name`)) %>%

  # left join to combine both csvs
  left_join(
    fips_lookup, 
    by = c("Div_Lower" = "alias")
  ) %>%
  
  # drop unused columns
  select(-c("Div_Lower", "official_name", "locality_type")) %>% 
  drop_na(fips_code) %>%
  
  # relocate new column
  relocate(fips_code, .after = "Div Name")

# write csv
write_csv(clean_data, here("data/outcome/Virginia-Department-of-Education/2022-2025_State_Testing.csv"))