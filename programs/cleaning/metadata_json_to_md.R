# scan the directory
source_dir <- here("data", "outcome")
all_files <- list.files(
  path = source_dir, 
  recursive = TRUE,  
  full.names = TRUE    
)

# filter out the master registry file
clean_files <- all_files %>% 
  str_subset("master_registry", negate = TRUE)

# get only json file
metadata_jsons <- str_subset(clean_files, "\\.json$")

# define output folder to store mds
output_dir <- here("data", "outcome", "markdown_metadata")
if (!dir.exists(output_dir)) {
  dir.create(output_dir, recursive = TRUE)
}

# track num of files converted (just to know everything converted after)
counter <- 0

# loop through json files
markdown_results <- map(metadata_jsons, function(json_path) {
  # read and parse json files into list
  meta_data <- jsonlite::fromJSON(txt = readLines(json_path, warn = FALSE), simplifyVector = FALSE)
  
  # extract top-level fields
  file_name     <- meta_data$file_name
  description   <- meta_data$desc
  organization  <- meta_data$organization
  geo_level     <- meta_data$geographic_level
  time_coverage <- meta_data$time_coverage 
  url_source    <- meta_data$url_source
  
  # extract nested spatial alignment
  spatial       <- meta_data$spatial_alignment
  fips_col      <- spatial$locality_fips
  name_col      <- spatial$locality_name
  
  # build the markdown header and metadata section
  md_text <- paste0(
    "# ", file_name, "\n\n",
    "**Description:** ", description, "\n\n",
    "- **Source Organization:** ", organization, "\n",
    "- **Geographic Coverage:** ", geo_level, "\n",
    "- **Temporal Coverage:** ", time_coverage, "\n",
    "- **URL Source:** [Link](", url_source, ")\n",
    "- **Spatial Alignment:** FIPS Column: `", fips_col, "`, Locality Column: `", name_col, "`\n\n",
    "### Column Schema\n\n"
  )
  
  # extract and loop through nested columns to format them as a Markdown list
  col_list <- meta_data$columns %||% list()
  if (length(col_list) > 0) {
    col_lines <- sapply(col_list, function(c) {
      name      <- c$name 
      data_type <- c$data_type 
      desc      <- c$desc 
      
      # extract keywords if they exist and collapse them into a comma-separated string
      keywords  <- c$keywords %||% list()
      kw_string <- if (length(keywords) > 0) paste(unlist(keywords), collapse = ", ") else "None"
      
      paste0("* **`", name, "`** (*", data_type, "*): ", desc, " *(Keywords: ", kw_string, ")*")
    })
    md_text <- paste0(md_text, paste(col_lines, collapse = "\n"), "\n")
  } else {
    md_text <- paste0(md_text, "*No column definitions found.*\n")
  }
  
  # save md file to folder
  json_filename <- basename(json_path)
  md_filename <- str_replace(json_filename, "\\.json$", ".md")
  md_filepath <- file.path(output_dir, md_filename)
  
  writeLines(md_text, con = md_filepath)
  
  # print that it actually converted
  counter <<- counter + 1
  print(paste0(counter, ". Successfully converted: ", json_filename))
  
  # return both the source file path and the generated Markdown string
  list(
    json_source = json_path,
    markdown_content = md_text,
    markdown_path = md_filepath
  )
})
