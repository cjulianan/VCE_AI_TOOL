library(tidycensus)
library(tidyverse)
library(arrow)
library(readr)
library(dplyr)

Sys.getenv("CENSUS_API_KEY")


v24 = load_variables(2024, "acs5", cache = TRUE) # this is dependent on tidycensus
View(v24)

# Our current list of parent codes we've collected
parent_tables <- c("B14005", "B06009", "B15001", "B14007", "B27019", "B27022", "B14003", "B17003",
                   "B27001", "B27010", "B27020", "B27002", "B27003", "B27011", "B27015", "B18101", 
                   "B18102", "B18103", "B18104", "B18105", "B18106", "B18107", "C27001", "C27004", 
                   "C27005", "C27007", "C27006", "C27008", "C27009", "C27012", "C27013", "C27014", 
                   "C27016", "C27017", "C27018", "C27021", "B22001", "B22002", "B22003", "B22005", 
                   "B22007", "B22010")

# Create storage list for wide data subsets collected per loop execution
yearly_storage <- list()

# 2. Outer Loop: Iterate chronologically through each target year
for (current_year in 2020:2024) {
  cat(paste("\n--- Processing data for year:", current_year, "---\n"))
  
  # Inner Loop: Extract each structural parent table from Census API
  table_list <- map(parent_tables, function(tbl_code) {
    cat(paste("Downloading table:", tbl_code, "\n"))
    
    # Core API Fetch
    df_raw <- get_acs(
      geography = "county",
      table     = tbl_code,
      state     = "VA",
      year      = current_year,
      survey    = "acs5",
      output    = "wide"
    )
    
    # Conditional MOE Processing:
    # If the table is NOT B15001, drop its Margin of Error columns immediately.
    # If it IS B15001, preserve them so you can study the raw structural NAs.
    if (tbl_code != "B15001") {
      df_processed <- df_raw %>% 
        select(-ends_with("M")) %>%
        rename_with(~str_remove(., "E$"), .cols = -c(GEOID, NAME))
    } else {
      # For B15001, drop nothing, but clean the estimate headers for uniform indexing
      df_processed <- df_raw %>%
        rename_with(~str_remove(., "E$"), .cols = ends_with("E"))
    }
    
    return(df_processed)
  })
  
  # Deterministic Join: Merges all tables side-by-side. 
  # Note: If any API call fails upstream, this step will intentionally throw an error 
  # for troubleshooting visibility.
  year_combined <- table_list %>% reduce(left_join, by = c("GEOID", "NAME"))
  
  # Append baseline geographic and temporal variables
  year_combined <- year_combined %>%
    mutate(year = current_year) %>%
    rename(FIPS = GEOID) %>%
    relocate(year, FIPS, NAME)
  
  # Store results under character-mapped year indices
  yearly_storage[[as.character(current_year)]] <- year_combined
}

# =========================================================================
# STEP 3: BIND & EXPORT COMPREHENSIVE REGISTRY
# =========================================================================
cat("\nStacking all years into master matrix...\n")
census_master_matrix <- bind_rows(yearly_storage)

# Export to raw validation file with text explicit NA assignments
write_csv(census_master_matrix, "census_master_county_raw.csv", na = "NA")
cat("SUCCESS: CSV exported to census_master_county_raw.csv\n")


############################

# 1. Isolate the target parent code
target_table <- "B15001"

# Create storage list for the yearly extracts
yearly_b15001_storage <- list()

# 2. Extract data from 2020 to 2024
for (current_year in 2020:2024) {
  cat(paste("\n--- Pulling B15001 raw data for year:", current_year, "---\n"))
  
  # Fetch the table wide, keeping absolutely everything (no select or rename filtering)
  df_raw <- get_acs(
    geography = "county",
    table     = target_table,
    state     = "VA",
    year      = current_year,
    survey    = "acs5",
    output    = "wide"
  )
  
  # Append baseline tracking variables
  year_combined <- df_raw %>%
    mutate(year = current_year) %>%
    rename(FIPS = GEOID) %>%
    relocate(year, FIPS, NAME)
  
  # Store under character-mapped year indices
  yearly_b15001_storage[[as.character(current_year)]] <- year_combined
}

# =========================================================================
# STEP 3: STACK & EXPORT THE MOE VALIDATION MATRIX
# =========================================================================
cat("\nStacking all years into B15001 validation matrix...\n")
b15001_master_matrix <- bind_rows(yearly_b15001_storage)

# Export with explicit "NA" strings so you can inspect the missing blocks in Excel
write_csv(b15001_master_matrix, "b15001_moe_validation.csv", na = "NA")
cat("SUCCESS: Isolated table exported to b15001_moe_validation.csv\n")
