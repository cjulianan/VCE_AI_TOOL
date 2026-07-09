library(dplyr)
library(readr)
library(stringr)


#### THIS SCRIPT CAN BE USED FOR OTHER DATASETS AS WELL THAT HAVE STATE AND COUNTY FIPS CODES BUT NOT THE 5 DIGIT ONE ####

# ---------------------------------------------
# 1. Define the folder containing NASS CSV files
# ---------------------------------------------
nass_folder <- file.path("data", "outcome", "National-Agricultural-Statistics-Service")

# ---------------------------------------------
# 2. List all CSV files inside that folder
# ---------------------------------------------
csv_files <- list.files(nass_folder, pattern = "\\.csv$", full.names = TRUE)

cat("Found", length(csv_files), "CSV files to process inside the directory.\n")

# ---------------------------------------------
# 3. Loop through each CSV file
# ---------------------------------------------
for (file_path in csv_files) {
  cat("\nProcessing:", basename(file_path), "\n")
  
  # Try reading the file safely
  try({
    # Read CSV, forcing the two code columns to be character
    df <- read_csv(
      file_path,
      col_types = cols(
        state_fips_code = col_character(),
        county_code = col_character(),
        .default = col_guess()
      )
    )
    
    # ---------------------------------------------
    # 4. Check if both required columns exist
    # ---------------------------------------------
    if (all(c("state_fips_code", "county_code") %in% names(df))) {
      
      # ---------------------------------------------
      # 5. Clean and pad the codes
      #     - state_fips_code → 2 digits
      #     - county_code → 3 digits
      # ---------------------------------------------
      df <- df %>%
        mutate(
          state_clean  = str_pad(str_trim(state_fips_code), width = 2, side = "left", pad = "0"),
          county_clean = str_pad(str_trim(county_code), width = 3, side = "left", pad = "0"),
          
          # ---------------------------------------------
          # 6. Create the 5-digit FIPS code
          # ---------------------------------------------
          fips_code = paste0(state_clean, county_clean)
        ) %>%
        select(-state_clean, -county_clean)  # remove helper columns
      
      # ---------------------------------------------
      # 7. Write updated CSV back to disk
      # ---------------------------------------------
      write_csv(df, file_path)
      
      cat(" -> Successfully added 'fips_code' to:", basename(file_path), "\n")
      
    } else {
      # Skip files missing required columns
      cat(" -> Skipped (Columns not found):", basename(file_path), "\n")
    }
    
  }, silent = TRUE)
}

cat("\nAll NASS folder datasets have been successfully processed!\n")
