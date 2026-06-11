library(tidycensus)
library(readr)
library(dplyr)

Sys.getenv("CENSUS_API_KEY")


# THESE ARE ALL PER COUNTY
education_variables <- c( 
  no_hs_grad = "B06009_002", # estimate of amount of people who did not graduate high school
  bachelors_degree = "B06009_005", # estimate of amount of people with a bachelors degree (not age specific)
  high_school_grad = "B06009_003", # estimate of amount of people who did not graduate high school (not age specific)
  male_18to24_bachelors = "B15001_009", # estimate of males 18 to 24 with a bachelors degree
  female_18to24_bachelors = "B15001_050", # estimate of females 18 to 24 with a bachelors degree
  female_notinschool_notinlaborforce = "B14005_029", # females not enrolled in school, not high school graduate, not in labor force
  house_foodstamps = "B22001_002" # estimate of households with foodstamps
  
  # After this I started to add Census parent codes to our shared Word Doc "ACS Codes" in Teams under VCE AI TOOL Channel
  # then Shared, Notes, ACS Variable Codes
)



storage = list()

for (current_year in 2020:2024) {
  cat (paste("Processing data for year: ", current_year))
  va_education = get_acs(
    geography = "county",
    variables = education_variables,
    state = "VA",
    year = current_year,
    survey = "acs5",
    output = "wide"
  )
  
  va_education = va_education %>%
    mutate(year = current_year)
  
  storage[[as.character(current_year)]] = va_education
}

va_education_binded = bind_rows(storage) %>%
  relocate(year)


view(va_education_binded)

