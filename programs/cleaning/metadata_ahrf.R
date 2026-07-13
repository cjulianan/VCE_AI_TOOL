library(readxl)
library(dplyr)
library(jsonlite)
library(stringr)

# 1. Load the Excel file directly using absolute path
crosswalk_path <- "C:/Users/nebiy/Downloads/AHRF_USER_TECH_2024-2025/Technical Documentation/AHRFCrosswalk2025.xlsx"
crosswalk_raw  <- read_excel(crosswalk_path)

# 2. Transform columns, clean abbreviations programmatically, and stitch together
columns_list <- crosswalk_raw %>%
  filter(!is.na(`FIELD-NEW NAME`)) %>%
  filter(`FIELD-NEW NAME` != "FIELD-NEW NAME" & `FIELD-NEW NAME` != "blank") %>%
  
  mutate(
    name        = as.character(`FIELD-NEW NAME`),
    var_clean   = if_else(is.na(`VARIABLE NAME`), "", trimws(as.character(`VARIABLE NAME`))),
    char_clean  = if_else(is.na(`CHARACTERISTICS`), "", trimws(as.character(`CHARACTERISTICS`))),
    cat_clean   = if_else(is.na(`CAT`), "UNK", trimws(as.character(`CAT`)))
  ) %>%
  
  mutate(
    # Programmatic translation layer using regex boundary rules (\\b) to swap full words only
    var_clean = str_replace_all(var_clean, c(
      "\\bPovty\\b"   = "Poverty",
      "\\bPov\\b"     = "Poverty",
      "\\bTypol\\b"   = "Typology",
      "\\bTyplgy\\b"  = "Typology",
      "\\bDestntn\\b" = "Destination",
      "\\bPopn\\b"    = "Population",
      "\\bPrim\\b"    = "Primary",
      "\\bCretn\\b"   = "Creation",
      "\\bCnty\\b"    = "County",
      "\\bSt\\b"      = "State"
    )),
    
    # Do the exact same expansion rule for the characteristics column strings
    char_clean = str_replace_all(char_clean, c(
      "\\bPovty\\b"   = "Poverty",
      "\\bPov\\b"     = "Poverty",
      "\\bTypol\\b"   = "Typology",
      "\\bTyplgy\\b"  = "Typology",
      "\\bDestntn\\b" = "Destination",
      "\\bPopn\\b"    = "Population",
      "\\bPrim\\b"    = "Primary",
      "\\bCretn\\b"   = "Creation",
      "\\bCnty\\b"    = "County",
      "\\bSt\\b"      = "State"
    ))
  ) %>%
  
  mutate(
    desc = paste0(
      "[Category: ", cat_clean, "] ", var_clean,
      if_else(char_clean != "", paste0(" (Details: ", char_clean, ")"), "")
    )
  ) %>%
  select(name, desc) %>%
  distinct(name, .keep_all = TRUE)

# 3. Make our structure for the metadata file (before the 4000+ column pairs come in)
ahrf_metadata <- list(
  dataset_id       = "Area Health Resources",
  file_name        = "health_resources_va.csv",
  file_path        = "data/outcome/Health-Resources-and-Services-Administration/health_resources_va.csv",
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

# 4. Export the comprehensive structural map back to my project directory
# im using here::here() now because im' writing to my local project space, not my downloads folder
write_json(ahrf_metadata, here::here("data/outcome/Health-Resources-and-Services-Administration/hrsa_ahrf_metadata.json"), pretty = TRUE, auto_unbox = TRUE)

message(paste("SUCCESS! Generated metadata file containing", nrow(columns_list), "variables."))
