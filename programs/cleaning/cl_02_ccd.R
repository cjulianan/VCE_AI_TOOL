# institutional-locality script -------------------------------------------

# The purpose of this script is to create a csv from the ccd directory dataset listing all school districts that span across more than one county

# read the path to ccd directory dataset
df <- read_csv("data/outcome/Urban-Institute/2020-2024_ccd_directory.csv")

overlapping_districts <- df %>%
  # group by school district id and filter for school districts with more than 1 county code attached to it
  group_by(leaid) %>%
  filter(n_distinct(county_code) > 1) %>%
  
  # filter by max year since different years may spell school district names differently
  filter(year == max(year)) %>%
  ungroup() %>%
  
  # select and rename columns for school district id, name , and fips code
  select(
    institution_id = leaid,
    institution_name = lea_name,
    locality_fips = county_code
  ) %>%
  
  # remove duplicates and add columns for relationship type and weight
  distinct() %>% 
  mutate(
    relationship_type = "serves",
    weight = "shared"
  ) %>%
  arrange(institution_id)

# save to csv
write_csv(overlapping_districts, "data/outcome/Urban-Institute/institution-locality_relationship_table.csv")