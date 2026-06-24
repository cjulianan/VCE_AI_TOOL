# Building Dataset ---------------------------------------------------------------

# Initialize years wanted and storage for storing each year's dataset
years <- 2022
storage <- list()

# Loop through each year
for (current_year in years) {
  cat(paste0("Processing year: "), current_year)
  
  crops_params <- list(
    source_desc = "CENSUS", 
    sector_desc = "ECONOMICS",
    group_desc = "IRRIGATION",
    year = current_year,
    state_name = "VIRGINIA",
    agg_level_desc = "COUNTY"
  )
  
  yearly_data <- nassqs(crops_params) %>% 
    select(
      -region_desc,
      -zip_5,
      -watershed_code,
      -watershed_desc,
      -congr_district_code,
      -country_code,
      -country_name,
      -begin_code,
      -end_code,
      -reference_period_desc,
      -load_time,
      -week_ending
    )
  
  # Store each year's data inside storage
  storage[[as.character(current_year)]] <- yearly_data
}

# Merge everything in storage
crops_data <- bind_rows(storage)

# Write csv
write_csv(crops_data, "census_nass_irrigation.csv")