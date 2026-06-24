library(jsonlite)

# 1. DEFINE YOUR ACTIVE PARENT CODES
# Replace these with your actual parent codes from your master CSV
active_parent_tables <- c("B14005", "B06009", "B15001", "B14007","B27019", "B27022", "B14003", "B14007", "B17003", 
                                             
                                             "B27001", "B27010", "B27020", "B27002", "B27003", "B27011", "B27015", "B18101", "B18102", 
                                             
                                             "B18103", "B18104", "B18105", "B18106", "B18107", "C27001", "C27004", "C27005", "C27007", 
                                             
                                             "C27006", "C27008", "C27009", "C27012", "C27013", "C27014", "C27016", "C27017", "C27018", 
                                             
                                             "C27021", "B22001", "B22002", "B22003", "B22005", "B22007", "B22010")

all_labels <- data.frame()

# 2. HARVEST THE LABELS FROM THE CENSUS BUREAU
print("Starting Census label harvest...")
for (table in active_parent_tables) {
  message(paste("Fetching variables for table:", table))
  
  api_url <- sprintf("https://api.census.gov/data/2022/acs/acs5/variables.json")
  
  # Fetch the massive master variables json list safely
  tryCatch({
    raw_json <- fromJSON(api_url)
    variables <- raw_json$variables
    
    # Filter the variables down to ONLY the ones matching this parent table code
    matching_codes <- names(variables)[grepl(paste0("^", table), names(variables))]
    
    for (code in matching_codes) {
      clean_label <- paste0(variables[[code]]$concept, " -> ", variables[[code]]$label)
      
      # Append this row into our temporary tracking dataframe
      all_labels <- rbind(all_labels, data.frame(
        variable_code = code,
        human_label   = clean_label,
        stringsAsFactors = FALSE
      ))
    }
  }, error = function(e) {
    message(paste("Error downloading table", table, ":", e$message))
  })
}

# 3. EXPORT TO YOUR GITHUB DIRECTORY
# Ensure this folder path matches your repository data structure
output_path <- file.path("data", "outcome", "census_dictionary.csv")
write.csv(all_labels, output_path, row.names = FALSE)
print(paste("Success! Local dictionary compiled and saved to:", output_path))
