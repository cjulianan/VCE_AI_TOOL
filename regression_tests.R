library(here)
library(jsonlite)

# 1. This function runs your prompt through your app's core routing logic
check_routing <- function(question) {
  user_prompt_clean <- tolower(trimws(question))
  
  # Load your data tables
  VIRGINIA_LOCALITIES <- read.csv(here("data/outcome/virginia_localities.csv"), stringsAsFactors = FALSE)
  VIRGINIA_LOCALITIES$alias <- tolower(VIRGINIA_LOCALITIES$alias)
  
  # Check for FIPS matching (Milestone 2)
  found_fips <- "NONE"
  for (i in 1:nrow(VIRGINIA_LOCALITIES)) {
    if (grepl(VIRGINIA_LOCALITIES$alias[i], user_prompt_clean)) {
      found_fips <- sprintf("%05d", as.integer(VIRGINIA_LOCALITIES$fips[i]))
      break
    }
  }
  return(found_fips)
}

# 2. THE AUTOMATED TRIPWIRES
cat("\n📢 RUNNING AUTOMATED REGRESSION TESTS...\n\n")

# TEST 4 CHECK
m_county_fips <- check_routing("Show fertilizer usage statistics for Montgomery County.")
if (m_county_fips == "51121") {
  cat("✅ TEST 4 PASSED: Montgomery County correctly routed to FIPS 51121!\n")
} else {
  cat("❌ TEST 4 FAILED: Expected FIPS 51121, but got: ", m_county_fips, "\n")
}

# TEST 5 CHECK
disease_fips <- check_routing("What does the disease surveillance data look like for Montgomery County?")
if (disease_fips == "51121") {
  cat("✅ TEST 5 PASSED: Disease data correctly routed to FIPS 51121!\n")
} else {
  cat("❌ TEST 5 FAILED: Expected FIPS 51121, but got: ", disease_fips, "\n")
}

cat("\n================ TESTS COMPLETE ================\n")