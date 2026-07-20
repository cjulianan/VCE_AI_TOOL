## ALL THE TOOLS DEFINED BELOW

# SUMMARIZE FUNCTION
summarize_func <- function(dataset_id, metric_column, operation, fips = NULL) {
  message("Used Data Tool!")
  conn <- get0("DB_CON", envir = .GlobalEnv)
  if (is.null(conn) || !DBI::dbIsValid(conn)) {
    return("Error: Database connection 'DB_CON' is missing or inactive in global memory.")
  }
  # 1. Strict structural allowlist (No brittle regex checks)
  valid_ops <- c("COUNT", "SUM", "AVG", "MIN", "MAX")
  operation <- toupper(trimws(operation))
  if (!operation %in% valid_ops) return("Error: Unsupported statistical operation.")
  
  # 2. Dataset ID Allowlist (Maps safe internal shortcodes to relative paths)
  # WE WILL ADD THE OTHER DATSETS LATER
  dataset_map <- list(
    "nass_crops"     = "data/outcome/census_nass_crops.csv",
    "vdh_diseases"   = "data/outcome/Virginia-Department-of-Health/reportable_disease_surveillance_virginia_geography.csv",
    "special_ed"     = "data/outcome/Virginia-Department-of-Education/2022-2023_Special_Education_Child_Count.csv",
    "depression"     = "data/outcome/Mental-Health-America/Depression_County_Map_Full_Data.csv"
  )
  
  file_path = dataset_map[[dataset_id]]
  if (is.null(file_path)) return("Error: Unregistered or unauthorized dataset ID.")
  
  # 3. Clean, Deterministic Parameterized Query Execution
  if (!is.null(fips) && fips != "") {
    # Wrapped column parameter in double quotes to handle spaces safely
    query <- sprintf('SELECT %s("%s") AS result FROM \'%s\' WHERE CAST(GEOID AS VARCHAR) = ?', operation, metric_column, file_path)
    # Pointed connection directly to the Global Environment
    res <- dbGetQuery(.GlobalEnv$DB_CON, query, params = list(as.character(fips)))
  } else {
    # Wrapped column parameter in double quotes to handle spaces safely
    query <- sprintf('SELECT %s("%s") AS result FROM \'%s\'', operation, metric_column, file_path)
    # Pointed connection directly to the Global Environment
    res <- dbGetQuery(.GlobalEnv$DB_CON, query)
  }
  
  # 4. Straightforward Output Handling
  if (nrow(res) == 0 || is.na(res$result[1])) return("No records matched the calculation criteria.")
  return(paste0("DuckDB Deterministic Result [", operation, "]: ", res$result[1]))
}


# summarize data tool
summarize_data_tool <- tool(
  summarize_func,
  name = "summarize_data",
  description = "Calculates math statistics (count, sum, avg, min, max) for a numeric column in an approved dataset. Use this instead of doing math yourself.",
  arguments = list(
    dataset_id = type_string("The approved shortcode ID of the dataset (e.g., 'nass_crops', 'vdh_diseases', 'special_ed')."),
    metric_column = type_string("The exact name of the database column to calculate."),
    operation = type_string("The calculation logic: 'count', 'sum', 'avg', 'min', or 'max'."),
    fips = type_string("Optional 5-digit geographic FIPS code to isolate a specific county or city.", required = FALSE)
  )
)