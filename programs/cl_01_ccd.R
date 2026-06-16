# Build ccd enrollment dataset -----------------------------------------------------------
ccd_enrollment <- get_education_data(
  level = "schools",
  source = "ccd",
  topic = "enrollment",
  subtopic = list("race", "sex"),
  filters = list(fips = 51, year = 2020:2024),
  add_labels = TRUE
) %>% 
  select(
    year,
    ncessch, # Official school id
    enrollment,
    leaid, # school district id
    grade,
    race,
    sex
  ) %>% 
  filter(
    enrollment > 0
  )

# View(ccd_enrollment)

# write csv
write_csv(ccd_enrollment, "2020-2024_ccd_enrollment.csv")