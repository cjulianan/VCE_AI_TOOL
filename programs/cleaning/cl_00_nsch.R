# Turning SAS file into CSV file to clean
# Have not started cleaning yet since this dataset covers only state level, not county level

sas_data <- read_sas("data/sources/US-Census-Bureau/nsch_2024e_topical.sas7bdat")
write_csv(sas_data, "data/outcome/US-Census-Bureau/converted_sas_data.csv")