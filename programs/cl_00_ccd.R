
# View column names -------------------------------------------------------

# ccd_directory <- get_education_data(
#   level = "schools",
#   source = "ccd",
#   topic = "directory",
#   filters = list(year = 2020:2024, state_location = "VA"),
#   add_labels = TRUE
# )
# 
# colnames(ccd_directory)


# Looking for problematic variables ---------------------------------------

# Show percentage of rows for each column that are NA, 0, or negative value
# sapply(ccd_directory, function(x) {
#   c(
#     pct_na = mean(is.na(x)) * 100,
#     pct_zero = if(is.numeric(x)) mean(x == 0, na.rm = TRUE) * 100 else 0,
#     pct_neg  = if(is.numeric(x)) mean(x < 0,  na.rm = TRUE) * 100 else 0
#   )
# })

# Build ccd directory dataset -----------------------------------------------------------

ccd_directory <- get_education_data(
  level = "schools",
  source = "ccd",
  topic = "directory",
  filters = list(year = 2020:2024, state_location = "VA"),
  add_labels = TRUE
) %>% 
  select(
    year, 
    school_name,
    ncessch,
    leaid, # id number for school district
    lea_name, # school district name
    
    county_code,
    city_location,
    urban_centric_locale, # if school is urban, rural, city, suburb etc.
    longitude,
    latitude,
    
    school_level,
    school_type, 
    charter,
    magnet,
    virtual,
    
    enrollment,
    teachers_fte, # full time teachers
    free_or_reduced_price_lunch,
    direct_certification # students with verified financial needs
  ) %>% 
  filter(
    enrollment > 0
  )

#View(ccd_directory)

# create csv
write_csv(ccd_directory, "2020-2024_ccd_directory.csv")
