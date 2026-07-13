library(readxl)
library(dplyr)
library(jsonlite)

# 1. Load the Excel file directly using your absolute path
crosswalk_path <- "C:/Users/nebiy/Downloads/AHRF_USER_TECH_2024-2025/Technical Documentation/AHRFCrosswalk2025.xlsx"
crosswalk_raw  <- read_excel(crosswalk_path)

# 2. Process and filter the data frame to extract ALL column variables
columns_list <- crosswalk_raw %>%
  # Force all column targets to strings and drop completely blank rows
  filter(!is.na(`FIELD-NEW NAME`)) %>%
  filter(`FIELD-NEW NAME` != "FIELD-NEW NAME" & `FIELD-NEW NAME` != "blank") %>%
  
  mutate(
    # Safely convert internal Excel cell types to text
    name       = as.character(`FIELD-NEW NAME`),
    var_clean  = as.character(`VARIABLE NAME`),
    char_clean = as.character(`CHARACTERISTICS`),
    cat_clean  = as.character(`CAT`),
    
    # Handle missing values (NA) safely so they don't print as literal "NA" text
    var_clean   = if_else(is.na(var_clean) | var_clean == "NA", "", trimws(var_clean)),
    char_clean  = if_else(is.na(char_clean) | char_clean == "NA", "", trimws(char_clean)),
    cat_clean   = if_else(is.na(cat_clean) | cat_clean == "NA", "UNK", trimws(cat_clean)),
    
    # Construct a clean, descriptive context block for the AI matching layer
    desc = paste0(
      "[Category: ", cat_clean, "] ", var_clean,
      if_else(char_clean != "", paste0(" (Details: ", char_clean, ")"), "")
    )
  ) %>%
  # Isolate only the two fields required by your normalize_metadata function
  select(name, desc) %>%
  distinct(name, .keep_all = TRUE)

# 3. Assemble your master system profile packet
ahrf_metadata <- list(
  dataset_id       = "Area Health Resources",
  file_name        = "ahrf_virginia.csv",
  file_path        = "data/outcome/ahrf_virginia.csv",
  desc             = "Health Resources and Services Administration (HRSA) Area Health Resources Files (AHRF). This county-level dataset features longitudinal indicators tracking healthcare worker distribution, clinical facility assets, utilization trends, and regional economic characteristics across Virginia.",
  organization     = "Health Resources and Services Administration (HRSA)",
  geographic_level = "County",
  time_coverage    = "2024-2025",
  spatial_alignment = list(
    locality_fips  = "secndry_entity_file", 
    locality_name  = "cnty_name"
  ),
  columns          = columns_list
)

# 4. Export the comprehensive structural map back to your project directory
# We use here::here() now because we are writing to your local project space, not your downloads folder
write_json(ahrf_metadata, here::here("data/outcome/Health-Resources-and-Services-Administration/hrsa_ahrf_metadata.json"), pretty = TRUE, auto_unbox = TRUE)

message(paste("SUCCESS! Generated metadata file containing", nrow(columns_list), "variables."))
