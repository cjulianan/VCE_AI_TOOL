
# Codebook ----------------------------------------------------------

# View acs5 codebook for 2024
v24 <- load_variables(2024, "acs5", cache = TRUE)
View(v24)

# Building table ----------------------------------------------------------

# Load variables
va_variables <- c(
  total_males = "B27001_006", # total males ages 6-18
  male_insured = "B27001_007", # total males with health insurance ages 6-18
  male_uninsured = "B27001_008", # total males without health insurance ages 6-18
  total_females = "B27001_034", # total females ages 6-18
  female_insured = "B27001_035", # total females with health insurance ages 6-18
  female_uninsured = "B27001_036" # total females without health insurance ages 6-18
)

# List to store each year's data
storage <- list()

for (current_year in 2020:2024) {
  cat (paste("Processing data for year: ", current_year))
  
  va_insurance_data <- get_acs(
    geography = "county",
    variables = va_variables,
    state     = "VA",
    survey    = "acs5",
    year      = current_year,
    output    = "wide" 
  )
  
  # Add percentage columns to table
  va_insurance_percentages <- va_insurance_data %>% 
    mutate(
      year = current_year,
      pct_male_insured = male_insuredE / total_malesE * 100, # percentage of males with health insurance ages 6-18
      pct_female_insured = female_insuredE / total_femalesE * 100, # percentage of females with health insurance ages 6-18
      total_pop = total_malesE + total_femalesE, # total population ages 6-18
      total_insured = male_insuredE + female_insuredE, # total population health insured ages 6-18
      pct_pop_insured = total_insured / total_pop * 100 # percentage health insured ages 6-18
    )
  
  storage[[as.character(current_year)]] <- va_insurance_percentages
}

# Merge
va_insurance_percentages_binded <- bind_rows(storage) %>% 
  relocate(year)

# Depends on if you want to view or create csv
View(va_insurance_percentages_binded)

write_csv(va_insurance_percentages_binded, "2020-2024_virginia_health_insurance.csv")