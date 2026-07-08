library(dplyr)
library(readr)

# -----------------------------
# 1. Read the dataset
# -----------------------------
ahrf <- read_csv(
  "data/sources/Health-Resources-and-Services-Administration/AHRF2025.csv",
  show_col_types = FALSE
)

# -----------------------------
# 2. Filter to Virginia only
# -----------------------------
ahrf_va <- ahrf %>%
  filter(st_name == "Virginia")

# -----------------------------
# 3. Compute missingness per column
# -----------------------------
missing_fraction <- ahrf_va %>%
  summarise(across(everything(), ~ mean(is.na(.)))) %>%
  unlist()

# -----------------------------
# 4. Report percentage of columns with ≥90% missing
# -----------------------------
num_cols <- length(missing_fraction)
num_high_missing <- sum(missing_fraction >= 0.90)
pct_high_missing <- round((num_high_missing / num_cols) * 100, 2)

cat("Total columns:", num_cols, "\n")
cat("Columns with >= 90% missingness:", num_high_missing,
    "(", pct_high_missing, "% )\n")

vars_90_missing <- names(missing_fraction)[missing_fraction >= 0.90]

cat("Variables with >= 90% missingness:\n")
print(vars_90_missing)

# -----------------------------
# 5. Drop columns with ≥90% missing
####### ENDED UP DECIDING NOT TO DROP, was simply curious

# -----------------------------
# keep_cols <- names(missing_fraction)[missing_fraction < 0.90]
# 
# ahrf_va_clean <- ahrf_va %>%
#   select(all_of(keep_cols))

# -----------------------------
# 6. Write cleaned CSV
# -----------------------------
write_csv(
  ahrf_va,
  "data/outcome/Health-Resources-and-Services-Administration/health_resources_va.csv"
)
