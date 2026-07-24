library(here)
library(ragnar)

# define where the registry store will be
db_path <- here("data", "outcome", "registry_store.duckdb")

# embed master registry ---------------------------------------------------

registry <- jsonlite::fromJSON(
  here("data", "outcome", "master_registry.json"),
  simplifyVector = FALSE
)

registry_rows <- purrr::map_dfr(
  registry$routing_registry,
  function(entry) {
    keywords <- paste(unlist(entry$keywords), collapse = ", ")
    text <- paste0(
      "Dataset ID: ", entry$dataset_id, "\n",
      "Keywords: ", keywords, "\n",
      "Metadata path: ", entry$metadata_path
    ) # makes master registry JSON into a Data Frame object
    
    tibble::tibble(
      origin = paste0("registry://", entry$dataset_id),
      hash = rlang::hash(text),
      text = text,
      dataset_id = entry$dataset_id,
      metadata_path = entry$metadata_path
    )
  }
)

# embed all other metadata ---------------------------------------------------

# define paths for json metadata files
metadata_dir <- here("data", "outcome")
metadata_files <- list.files(metadata_dir, pattern = "\\.json$", full.names = TRUE, recursive = TRUE)

# exclude master_registry.json so it isn't processed twice
metadata_files <- metadata_files[!grepl("master_registry\\.json$", metadata_files)]

metadata_rows <- purrr::map_dfr(
  metadata_files,
  function(file_path) {
    meta <- jsonlite::fromJSON(file_path, simplifyVector = FALSE)
    
    # process column-level schemas with flexible fallback logic
    col_list <- meta$columns %||% list()
    col_text_lines <- sapply(col_list, function(c) {
      # fallback for column identifier (is usually name but is variable_name for acs)
      col_name <- c$name %||% c$variable_code %||% "Unknown"
      
      # fallback for description (is usually desc but is human_label for acs)
      raw_desc <- c$desc %||% c$human_label %||% "No description"
      
      # clean up census labels like "Estimate!!Total:!!" if human_label is used
      clean_desc <- gsub("Estimate!!Total:!!", "Total for ", raw_desc)
      clean_desc <- gsub("!!", " ", clean_desc)
      
      # in case keywords array if missing (for hrsa ahrf)
      kw_list <- unlist(c$keywords %||% list())
      col_kw   <- if (length(kw_list) > 0) paste(kw_list, collapse = ", ") else "N/A"
  
      paste0("  - Column: ", col_name, " | Desc: ", clean_desc, " | Keywords: ", col_kw)
    })
    
    # combines all attributes into a line
    columns_formatted <- paste(col_text_lines, collapse = "\n")
    
    # build detailed text representation for vector search
    text <- paste0(
      "Dataset File: ", meta$file_name %||% basename(file_path), "\n",
      "Description: ", meta$desc %||% "N/A", "\n",
      "Organization: ", meta$organization %||% "N/A", "\n",
      "Geographic Level: ", meta$geographic_level %||% "N/A", "\n",
      "Time Coverage: ", meta$time_coverage %||% "N/A", "\n",
      "Columns Schema:\n", columns_formatted
    )
    
    # format into data frame for embeddings
    dataset_id_val <- tools::file_path_sans_ext(basename(file_path))
    tibble::tibble(
      origin = paste0("metadata://", dataset_id_val),
      hash = rlang::hash(text),
      text = text,
      dataset_id = dataset_id_val,
      metadata_path = file_path
    )
  }
)

# combine both master registry and all metadata into a single data frame
all_rows <- dplyr::bind_rows(registry_rows, metadata_rows)

# create registry store
store <- ragnar_store_create(
  location = db_path,
  overwrite = TRUE,
  version = 1,
  embed = embed_ollama(model = "nomic-embed-text:latest"),
  extra_cols = data.frame(
    dataset_id = character(),
    metadata_path = character()
  )
)

ragnar_store_insert(store, all_rows)
ragnar_store_build_index(store)

message("Successfully indexed master registry and ", length(metadata_files), " metadata JSON files into: ", db_path)