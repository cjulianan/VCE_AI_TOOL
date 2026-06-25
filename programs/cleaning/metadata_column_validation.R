# Purpose of this script is to make sure metadata json file contains all the exact columns from its corresponding dataset csv file

# Setup json and csv vectors ----------------------------------------------

# scan entire data/outcome folder for all the csv and json files within
source_dir <- here("data", "outcome")
all_files <- list.files(
  path = source_dir, 
  recursive = TRUE,  
  full.names = TRUE    
)
  # ACS will use the dictionary csv to match parent codes instead of a metadata json like others so filtered out for now
clean_files <- all_files %>% str_subset("American-Community-Survey", negate = TRUE)

# all metadata are .json and all datasets are csvs
metadata_jsons <- str_subset(clean_files, "\\.json$")
dataset_csvs <- str_subset(clean_files, "\\.csv$")


# Metadata column validation ----------------------------------------------

for (json_path in metadata_jsons) {
  json_name <- basename(json_path)
  
  # strip out "_metadata" (the name of each json file is the same as csv file but with _metadata added to end) and replaces with .csv to find matching CSV
  expected_csv <- str_replace(json_name, "_metadata\\.json$", ".csv")
  csv_match <- dataset_csvs[basename(dataset_csvs) == expected_csv]
  
  # read metadata keys and csv headers
  meta_list <- fromJSON(json_path, simplifyVector = FALSE)
  csv_cols  <- colnames(read_csv(csv_match, n_max = 0, show_col_types = FALSE))
  
  # flatten and grab strings with the key of "name" (this is the column name) anywhere inside the JSON
  meta_cols <- unlist(meta_list)
  meta_cols <- unique(meta_cols[str_detect(names(meta_cols), "\\.name$")])
  
  # compares columns by subtracting all the metadata columns from csv columns
  missing_in_json <- setdiff(csv_cols, meta_cols)
  
  # output results (0 length means no differences, everything else means there were differences)
  if (length(missing_in_json) == 0) {
    message("Success: All CSV columns found in ", expected_csv)
  } 
  else {
    # pulls actual missing columns
    actual_missing <- csv_cols[csv_cols %in% missing_in_json]
    
    message("Mismatch in ", json_name, ": Missing columns: ", paste(actual_missing, collapse = ", "))
  }
}