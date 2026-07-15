# read the master registry json file
json_data <- fromJSON("data/outcome/master_registry.json", simplifyVector = FALSE)

# header for md file
md_lines <- c("# Master Routing Registry\n")

# loop through the master registry json file
for (item in json_data$routing_registry) {
  # Get the titles of each metadata set from the path
  file_name <- tools::file_path_sans_ext(basename(item$metadata_path))
  clean_title <- gsub("_", " ", file_name)
  clean_title <- paste0(toupper(substring(clean_title, 1, 1)), substring(clean_title, 2))
  
  # Format each block of metadata to have the title, path, and keywords
  block <- c(
    paste("## Dataset:", clean_title),
    paste("- **Metadata Path**:", item$metadata_path),
    paste("- **Keywords**:", paste(item$keywords, collapse = ", ")),
    ""
  )
  md_lines <- c(md_lines, block)
}

# Save file as metadata
writeLines(md_lines, here("data/outcome/master_registry.md"))