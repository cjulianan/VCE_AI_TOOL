# Codebook ----------------------------------------------------------

# View acs5 codebook for 2024
# v24 <- load_variables(2024, "acs5", cache = TRUE)
# View(v24)


# Preparing variable codes ----------------------------------------------------------

years <- 2020:2024

# table for standard parent variable codes without race
# meanings behind variable codes are in ACS variable code doc
standard_tables <- c("B14005", "B06009", "B15001","B27019", "B27022", "B14003", "B14007", "B17003", "B27001", "B27010", "B27020", "B27002", "B27003", "B27011", "B27015", "B18102", "B18103", "B18104", "B18105", "B18106", "B18107", "C27004", "C27005", "C27007", "C27006", "C27008", "C27009", "C27012", "C27013", "C27014", "C27016", "C27017", "C27018", "C27021", "B22001", "B22002", "B22003", "B22007", "B22010") 

# append letters A-I to each parent variable codes with race automatically and combine them with standard_tables
tables_with_race <- c("B18101", "C27001", "B22005")
race_letters  <- LETTERS[1:9] 
race_variants <- map(tables_with_race, ~ paste0(.x, race_letters)) %>% unlist()
table_ids <- c(standard_tables, race_variants)

# Building tables ---------------------------------------------------------

# Loop through each year and table
va_data <- map_dfr(years, function(yr) {
  year_data <- map_dfr(table_ids, function(tb) {
    print(paste0("Processing table ", tb, " for year ", yr))
    
    get_acs(
      geography = "county",
      table     = tb,
      state     = "VA",
      survey    = "acs5",
      year      = yr,
      output    = "tidy"
    )
  }) %>% 
    # add year column
    mutate(year = yr) %>% 
    # filter out columns ending in "M" (margin of errors should be calculated with data agent)
    select(-moe) %>% 
    # reorganize into variable codes as columns and estimates as values of those columns
    pivot_wider(
      names_from = variable, 
      values_from = estimate
    ) %>%   # put year column to very left
    relocate(year)
  
  return(year_data)
}) 

# create csv
write_csv(va_data, "data/outcome/American-Community-Survey/2020-2024_acs_master_county.csv")

# Test for NAs ------------------------------------------------------------

# va_data_na <- va_data
# va_data_na %>% 
#   select(where(~ any(is.na(.)))) %>%  
#   write_csv("only_cols_with_na.csv")